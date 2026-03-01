from __future__ import annotations

from dataclasses import dataclass
from datetime import date
from typing import Dict, Iterable, List, Optional, Sequence, Set, Tuple

import pyodbc


@dataclass(frozen=True)
class Slot:
    ma_ca: int
    ngay_thi: date
    thu_tu: int


@dataclass(frozen=True)
class Room:
    ma_phong: str
    suc_chua: int


@dataclass(frozen=True)
class GroupAssignment:
    ma_phong: str
    students: List[str]


@dataclass
class OptimizeResult:
    created_lich: int
    created_assignments: int
    unscheduled_mon: List[str]
    total_exam_days: int = 0
    total_slots_used: int = 0


def _days_diff(a: date, b: date) -> int:
    return abs((a - b).days)


def _score_spread(
    slot: Slot, students: List[str],
    student_exam_dates: Dict[str, List[date]],
) -> float:
    """Higher → exams more spread out for enrolled students."""
    min_gap = float('inf')
    any_dates = False
    for sv in students:
        for d in student_exam_dates.get(sv, []):
            any_dates = True
            gap = _days_diff(d, slot.ngay_thi)
            if gap < min_gap:
                min_gap = gap
    return float(min_gap) if any_dates else 10000.0


def _score_compact(
    slot: Slot, slot_index: int,
    used_dates: Set[date], total_slots: int,
) -> float:
    """Higher → more compact (reuse exam days, prefer earlier slots)."""
    score = 0.0
    if slot.ngay_thi in used_dates:
        score += 100000.0
    score += float(total_slots - slot_index)
    return score


def optimize_schedule(
    conn: pyodbc.Connection,
    *,
    mode: str = "balanced",
    min_gap_days: int = 0,
    clear_existing: bool = True,
    auto_note: str = "AUTO",
) -> OptimizeResult:
    """Tạo lịch thi từ bảng DangKy.

    Ràng buộc:
    - Một phòng chỉ có 1 lịch trong 1 ca (đã có UQ_LT_Phong_Ca).
    - 1 sinh viên không được có 2 lịch trùng ca.
    - (Tuỳ chọn) khoảng cách ngày thi tối thiểu giữa các môn của cùng SV.

    Chiến lược (greedy):
    - Xếp môn đông SV trước.
    - Với mỗi môn, chọn ca sớm nhất thoả: không xung đột SV, đủ tổng sức chứa phòng đang rảnh.
    - Chia SV theo nhiều phòng trong cùng ca.
    """

    if min_gap_days < 0:
        raise ValueError("min_gap_days phải >= 0")

    cur = conn.cursor()

    # 1) Load registrations
    cur.execute(
        """
        SELECT MaMon, MaSinhVien
        FROM dbo.DangKy
        ORDER BY MaMon, MaSinhVien
        """
    )
    reg_rows = cur.fetchall()

    mon_to_students: Dict[str, List[str]] = {}
    for ma_mon, ma_sv in reg_rows:
        mon_to_students.setdefault(str(ma_mon), []).append(str(ma_sv))

    # 2) Load slots
    cur.execute(
        """
        SELECT MaCa, NgayThi, ThuTuTrongNgay
        FROM dbo.CaThi
        ORDER BY NgayThi, ThuTuTrongNgay
        """
    )
    slots: List[Slot] = [Slot(int(r[0]), r[1], int(r[2])) for r in cur.fetchall()]

    # 3) Load room availability by slot
    cur.execute(
        """
        SELECT ctp.MaCa, p.MaPhong, p.SucChua
        FROM dbo.CaThi_PhongThi ctp
        JOIN dbo.PhongThi p ON p.MaPhong = ctp.MaPhong
        WHERE ctp.TrangThai = N'SanSang'
        ORDER BY ctp.MaCa, p.SucChua DESC, p.MaPhong
        """
    )
    slot_rooms: Dict[int, List[Room]] = {}
    for ma_ca, ma_phong, suc_chua in cur.fetchall():
        slot_rooms.setdefault(int(ma_ca), []).append(Room(str(ma_phong), int(suc_chua)))

    # 4) Optionally clear existing schedules
    if clear_existing:
        # Xoá toàn bộ lịch hiện có (cascade sẽ dọn LichThi_SinhVien và LichThi_GiamThi)
        cur.execute("DELETE FROM dbo.LichThi_SinhVien")
        cur.execute("DELETE FROM dbo.LichThi_GiamThi")
        cur.execute("DELETE FROM dbo.LichThi")

    # 5) State for constraints
    used_room_in_slot: Set[Tuple[int, str]] = set()  # (MaCa, MaPhong)
    student_slots: Dict[str, Set[int]] = {}  # MaSinhVien -> set(MaCa)
    student_exam_dates: Dict[str, List[date]] = {}  # MaSinhVien -> list(date)
    used_dates: Set[date] = set()  # Ngày đã có lịch thi (cho compact scoring)

    def student_ok_for_slot(student_id: str, slot: Slot) -> bool:
        if slot.ma_ca in student_slots.get(student_id, set()):
            return False
        if min_gap_days > 0:
            for d in student_exam_dates.get(student_id, []):
                if _days_diff(d, slot.ngay_thi) < min_gap_days:
                    return False
        return True

    # 6) Schedule courses (largest first)
    mons_sorted = sorted(mon_to_students.items(), key=lambda kv: len(kv[1]), reverse=True)

    created_lich = 0
    created_assignments = 0
    unscheduled: List[str] = []
    created_lich_ids: List[int] = []

    for ma_mon, students in mons_sorted:
        if not students:
            continue

        best_score = -float('inf')
        chosen_slot: Optional[Slot] = None
        chosen_groups: Optional[List[GroupAssignment]] = None

        for idx, slot in enumerate(slots):
            rooms_all = slot_rooms.get(slot.ma_ca, [])
            if not rooms_all:
                continue

            # Rooms free in this slot
            rooms_free = [r for r in rooms_all if (slot.ma_ca, r.ma_phong) not in used_room_in_slot]
            if not rooms_free:
                continue

            # Capacity check (total)
            total_cap = sum(r.suc_chua for r in rooms_free)
            if total_cap < len(students):
                continue

            # Student conflict check
            if any(not student_ok_for_slot(sv, slot) for sv in students):
                continue

            # Build grouping: fill biggest rooms first
            remaining = list(students)
            groups: List[GroupAssignment] = []
            for room in rooms_free:
                if not remaining:
                    break
                take = min(room.suc_chua, len(remaining))
                groups.append(GroupAssignment(ma_phong=room.ma_phong, students=remaining[:take]))
                remaining = remaining[take:]

            if remaining:
                continue

            # ---- Score this feasible slot based on optimisation mode ----
            if mode == "spread":
                score = (
                    _score_spread(slot, students, student_exam_dates) * 1000.0
                    + float(len(slots) - idx)
                )
            elif mode == "compact":
                score = _score_compact(slot, idx, used_dates, len(slots))
            else:  # balanced
                sp = _score_spread(slot, students, student_exam_dates)
                co = _score_compact(slot, idx, used_dates, len(slots))
                score = min(sp, 3.0) * 50000.0 + co

            if score > best_score:
                best_score = score
                chosen_slot = slot
                chosen_groups = groups

        if chosen_slot is None or chosen_groups is None:
            unscheduled.append(ma_mon)
            continue

        # 7) Persist chosen schedule
        for group in chosen_groups:
            cur.execute(
                """
                INSERT INTO dbo.LichThi (MaMon, MaCa, MaPhong, TrangThai, GhiChu)
                OUTPUT INSERTED.MaLich
                VALUES (?, ?, ?, N'Nhap', ?)
                """,
                ma_mon,
                chosen_slot.ma_ca,
                group.ma_phong,
                auto_note,
            )
            ma_lich = int(cur.fetchone()[0])
            created_lich += 1
            created_lich_ids.append(ma_lich)

            # Assign students to this MaLich
            rows = [(ma_lich, sv) for sv in group.students]
            if rows:
                cur.fast_executemany = True
                cur.executemany(
                    "INSERT INTO dbo.LichThi_SinhVien (MaLich, MaSinhVien) VALUES (?, ?)",
                    rows,
                )
                created_assignments += len(rows)

        # 8) Update state
        used_dates.add(chosen_slot.ngay_thi)
        for group in chosen_groups:
            used_room_in_slot.add((chosen_slot.ma_ca, group.ma_phong))
        for sv in students:
            student_slots.setdefault(sv, set()).add(chosen_slot.ma_ca)
            student_exam_dates.setdefault(sv, []).append(chosen_slot.ngay_thi)

    all_slot_ids = {ma_ca for ma_ca, _ in used_room_in_slot}

    assign_invigilators_for_lich_ids(conn, created_lich_ids, per_lich=2)

    return OptimizeResult(
        created_lich=created_lich,
        created_assignments=created_assignments,
        unscheduled_mon=unscheduled,
        total_exam_days=len(used_dates),
        total_slots_used=len(all_slot_ids),
    )


def ensure_missing_invigilators(conn: pyodbc.Connection, *, per_lich: int = 2) -> int:
    """Đảm bảo mọi lịch thi hiện có đều có đủ giám thị.

    - Với mỗi MaLich: nếu đang có <2 giám thị thì sẽ gán đủ 2.
    - Trong cùng MaCa: một giám thị không bị gán trùng nhiều phòng.
    """

    cur = conn.cursor()
    cur.execute(
        """
        SELECT lt.MaLich
        FROM dbo.LichThi lt
        LEFT JOIN dbo.LichThi_GiamThi ltgt ON ltgt.MaLich = lt.MaLich
        GROUP BY lt.MaLich
        HAVING COUNT(ltgt.MaGiamThi) < ?
        ORDER BY lt.MaLich
        """,
        per_lich,
    )
    lich_ids = [int(r[0]) for r in cur.fetchall()]
    if not lich_ids:
        return 0
    return _assign_invigilators_for_lich(conn, cur, lich_ids, per_lich=per_lich)


def assign_invigilators_for_lich_ids(
    conn: pyodbc.Connection,
    lich_ids: Sequence[int],
    *,
    per_lich: int = 2,
) -> int:
    """Gán giám thị cho danh sách MaLich (nếu thiếu)."""

    if not lich_ids:
        return 0
    cur = conn.cursor()
    return _assign_invigilators_for_lich(conn, cur, lich_ids, per_lich=per_lich)


def _assign_invigilators_for_lich(
    conn: pyodbc.Connection,
    cur: pyodbc.Cursor,
    lich_ids: Sequence[int],
    *,
    per_lich: int = 2,
) -> int:
    """Gán giám thị cho danh sách MaLich.

    Quy tắc:
    - Mỗi MaLich có đúng 2 giám thị (ThuTu 1..2).
    - Trong cùng một MaCa (cùng thời điểm), mỗi giám thị chỉ được coi tối đa 1 phòng.

    Nếu thiếu giám thị, tự tạo thêm trong bảng dbo.GiamThi.
    """

    if per_lich != 2:
        raise ValueError("Hệ thống hiện hỗ trợ per_lich=2 theo constraint CK_LTGT_ThuTu")

    if not lich_ids:
        return 0

    # Ensure schema has GiamThi (LichThi.sql có, nhưng seed reset có thể xoá sạch dữ liệu).
    cur.execute(
        """
        SELECT 1
        FROM INFORMATION_SCHEMA.TABLES
        WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'GiamThi'
        """
    )
    if cur.fetchone() is None:
        return 0

    # Only assign for MaLich that currently has < 2 supervisors.
    placeholders = ",".join(["?"] * len(lich_ids))
    cur.execute(
        f"""
        SELECT lt.MaLich
        FROM dbo.LichThi lt
        LEFT JOIN dbo.LichThi_GiamThi ltgt ON ltgt.MaLich = lt.MaLich
        WHERE lt.MaLich IN ({placeholders})
        GROUP BY lt.MaLich
        HAVING COUNT(ltgt.MaGiamThi) < ?
        ORDER BY lt.MaLich
        """,
        (*[int(x) for x in lich_ids], per_lich),
    )
    target_lich = [int(r[0]) for r in cur.fetchall()]
    if not target_lich:
        return 0

    # Fetch (MaLich, MaCa) for targets, grouped by MaCa.
    placeholders = ",".join(["?"] * len(target_lich))
    cur.execute(
        f"""
        SELECT lt.MaLich, lt.MaCa
        FROM dbo.LichThi lt
        WHERE lt.MaLich IN ({placeholders})
        ORDER BY lt.MaCa, lt.MaPhong, lt.MaMon, lt.MaLich
        """,
        (*[int(x) for x in target_lich],),
    )
    lich_with_ca = [(int(r[0]), int(r[1])) for r in cur.fetchall()]

    # Load active invigilators.
    cur.execute(
        """
        SELECT MaGiamThi
        FROM dbo.GiamThi
        WHERE TrangThai = N'DangLam'
        ORDER BY MaGiamThi
        """
    )
    invigilators = [str(r[0]) for r in cur.fetchall()]

    # Ensure we have enough invigilators to cover the maximum number of rooms in any single MaCa.
    by_ca: Dict[int, List[int]] = {}
    for ma_lich, ma_ca in lich_with_ca:
        by_ca.setdefault(ma_ca, []).append(ma_lich)
    max_need_in_slot = max((per_lich * len(v) for v in by_ca.values()), default=0)

    if len(invigilators) < max_need_in_slot:
        to_create = max_need_in_slot - len(invigilators)
        cur.execute("SELECT MaGiamThi FROM dbo.GiamThi")
        used_ids = {str(r[0]) for r in cur.fetchall()}

        new_rows: List[tuple] = []
        seq = 1
        while len(new_rows) < to_create:
            ma_gt = f"GT{seq:03d}"
            seq += 1
            if ma_gt in used_ids:
                continue
            used_ids.add(ma_gt)
            ho_ten = f"Giám thị {ma_gt}"
            don_vi = "Phòng Khảo thí"
            dien_thoai = None
            email = None
            trang_thai = "DangLam"
            new_rows.append((ma_gt, ho_ten, don_vi, dien_thoai, email, trang_thai))

        if new_rows:
            cur.fast_executemany = True
            cur.executemany(
                """
                INSERT INTO dbo.GiamThi (MaGiamThi, HoTen, DonVi, DienThoai, Email, TrangThai)
                VALUES (?, ?, ?, ?, ?, ?)
                """,
                new_rows,
            )
            invigilators.extend([r[0] for r in new_rows])

    if len(invigilators) < max_need_in_slot:
        raise RuntimeError(
            f"Không đủ giám thị để gán 2 người/Phòng trong cùng 1 ca. Cần {max_need_in_slot}, hiện có {len(invigilators)}."
        )

    # Assign 2 supervisors per schedule entry, with uniqueness within each MaCa.
    rows: List[tuple] = []
    global_offset = 0
    for ma_ca, lich_list in by_ca.items():
        used_in_slot: Set[str] = set()
        idx = global_offset % len(invigilators)
        global_offset += per_lich * len(lich_list)

        for ma_lich in lich_list:
            cur.execute("DELETE FROM dbo.LichThi_GiamThi WHERE MaLich = ?", int(ma_lich))
            for thu_tu in (1, 2):
                # pick next invigilator not yet used in this slot
                while invigilators[idx] in used_in_slot:
                    idx = (idx + 1) % len(invigilators)
                ma_gt = invigilators[idx]
                idx = (idx + 1) % len(invigilators)
                used_in_slot.add(ma_gt)
                rows.append((int(ma_lich), int(thu_tu), str(ma_gt)))

    if rows:
        cur.fast_executemany = True
        cur.executemany(
            "INSERT INTO dbo.LichThi_GiamThi (MaLich, ThuTu, MaGiamThi) VALUES (?, ?, ?)",
            rows,
        )
    return len(rows)


def fetch_schedule_summary(conn: pyodbc.Connection) -> List[dict]:
    cur = conn.cursor()
    cur.execute(
        """
        SELECT
            lt.MaLich,
            lt.MaMon,
            mt.TenMon,
            ct.NgayThi,
            ct.ThuTuTrongNgay,
            ct.GioBatDau,
            ct.GioKetThuc,
            lt.MaPhong,
            pt.TenPhong,
            pt.SucChua,
            COUNT(lsv.MaSinhVien) AS SoSinhVien,
            lt.GhiChu
        FROM dbo.LichThi lt
        JOIN dbo.MonThi mt ON mt.MaMon = lt.MaMon
        JOIN dbo.CaThi ct ON ct.MaCa = lt.MaCa
        JOIN dbo.PhongThi pt ON pt.MaPhong = lt.MaPhong
        LEFT JOIN dbo.LichThi_SinhVien lsv ON lsv.MaLich = lt.MaLich
        GROUP BY
            lt.MaLich, lt.MaMon, mt.TenMon,
            ct.NgayThi, ct.ThuTuTrongNgay, ct.GioBatDau, ct.GioKetThuc,
            lt.MaPhong, pt.TenPhong, pt.SucChua,
            lt.GhiChu
        ORDER BY ct.NgayThi, ct.ThuTuTrongNgay, lt.MaMon, lt.MaPhong, lt.MaLich
        """
    )
    out: List[dict] = []
    for r in cur.fetchall():
        so_sv = int(r[10])
        suc_chua = int(r[9])
        out.append(
            {
                "MaLich": int(r[0]),
                "MaMon": str(r[1]),
                "TenMon": str(r[2]),
                "NgayThi": r[3].isoformat(),
                "ThuTuTrongNgay": int(r[4]),
                "GioBatDau": str(r[5]),
                "GioKetThuc": str(r[6]),
                "MaPhong": str(r[7]),
                "TenPhong": str(r[8]),
                "SucChua": suc_chua,
                "SoSinhVien": so_sv,
                "PhanTramLap": round(so_sv / suc_chua * 100) if suc_chua > 0 else 0,
                "GhiChu": (str(r[11]) if r[11] is not None else ""),
            }
        )
    return out


def fetch_room_details(conn: pyodbc.Connection) -> dict:
    """Trả về dict: MaLich -> {giamthi: [...], sinhvien: [...]}"""
    # Safety net: if schedules exist but supervisors were not assigned
    # (e.g., old runs / multiple server instances), ensure they are filled.
    try:
        ensure_missing_invigilators(conn)
    except Exception:
        # Do not break page rendering if auto-assign fails; caller can still see students.
        pass
    cur = conn.cursor()

    # Giám thị theo lịch
    cur.execute(
        """
        SELECT ltgt.MaLich, ltgt.ThuTu, gt.MaGiamThi, gt.HoTen, gt.DonVi
        FROM dbo.LichThi_GiamThi ltgt
        JOIN dbo.GiamThi gt ON gt.MaGiamThi = ltgt.MaGiamThi
        ORDER BY ltgt.MaLich, ltgt.ThuTu
        """
    )
    details: dict = {}
    for r in cur.fetchall():
        ma_lich = int(r[0])
        details.setdefault(ma_lich, {"giamthi": [], "sinhvien": []})
        details[ma_lich]["giamthi"].append({
            "ThuTu": int(r[1]),
            "MaGiamThi": str(r[2]),
            "HoTen": str(r[3]),
            "DonVi": str(r[4]) if r[4] else "",
        })

    # Sinh viên theo lịch
    cur.execute(
        """
        SELECT ltsv.MaLich, sv.MaSinhVien, sv.HoTen, sv.Lop
        FROM dbo.LichThi_SinhVien ltsv
        JOIN dbo.SinhVien sv ON sv.MaSinhVien = ltsv.MaSinhVien
        ORDER BY ltsv.MaLich, sv.MaSinhVien
        """
    )
    for r in cur.fetchall():
        ma_lich = int(r[0])
        details.setdefault(ma_lich, {"giamthi": [], "sinhvien": []})
        details[ma_lich]["sinhvien"].append({
            "MaSinhVien": str(r[1]),
            "HoTen": str(r[2]),
            "Lop": str(r[3]) if r[3] else "",
        })

    return details


def fetch_student_schedules(conn: pyodbc.Connection) -> List[dict]:
    """Trả về danh sách SV, mỗi SV có list các lịch thi của họ."""
    cur = conn.cursor()
    cur.execute(
        """
        SELECT
            sv.MaSinhVien, sv.HoTen, sv.Lop,
            lt.MaLich, lt.MaMon, mt.TenMon,
            ct.NgayThi, ct.ThuTuTrongNgay, ct.GioBatDau, ct.GioKetThuc,
            lt.MaPhong, pt.TenPhong
        FROM dbo.LichThi_SinhVien ltsv
        JOIN dbo.SinhVien sv ON sv.MaSinhVien = ltsv.MaSinhVien
        JOIN dbo.LichThi lt ON lt.MaLich = ltsv.MaLich
        JOIN dbo.MonThi mt ON mt.MaMon = lt.MaMon
        JOIN dbo.CaThi ct ON ct.MaCa = lt.MaCa
        JOIN dbo.PhongThi pt ON pt.MaPhong = lt.MaPhong
        ORDER BY sv.MaSinhVien, ct.NgayThi, ct.ThuTuTrongNgay
        """
    )
    sv_map: dict = {}
    sv_order: List[str] = []
    for r in cur.fetchall():
        ma_sv = str(r[0])
        if ma_sv not in sv_map:
            sv_map[ma_sv] = {
                "MaSinhVien": ma_sv,
                "HoTen": str(r[1]),
                "Lop": str(r[2]) if r[2] else "",
                "exams": [],
            }
            sv_order.append(ma_sv)
        sv_map[ma_sv]["exams"].append({
            "MaLich": int(r[3]),
            "MaMon": str(r[4]),
            "TenMon": str(r[5]),
            "NgayThi": r[6].isoformat(),
            "ThuTuTrongNgay": int(r[7]),
            "GioBatDau": str(r[8]),
            "GioKetThuc": str(r[9]),
            "MaPhong": str(r[10]),
            "TenPhong": str(r[11]),
        })
    return [sv_map[k] for k in sv_order]
