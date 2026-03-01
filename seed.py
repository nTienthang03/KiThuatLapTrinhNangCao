from __future__ import annotations

from dataclasses import dataclass
from datetime import date, time
from pathlib import Path
from typing import Iterable

import pyodbc


@dataclass
class SeedResult:
    reset: bool
    inserted_students: int = 0
    inserted_courses: int = 0
    inserted_rooms: int = 0
    inserted_invigilators: int = 0
    inserted_slots: int = 0
    inserted_availability: int = 0
    inserted_registrations: int = 0


def _table_exists(cur: pyodbc.Cursor, table_name: str) -> bool:
    cur.execute(
        """
        SELECT 1
        FROM INFORMATION_SCHEMA.TABLES
        WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = ?
        """,
        table_name,
    )
    return cur.fetchone() is not None


def _ensure_schema(cur: pyodbc.Cursor) -> None:
    required = [
        "SinhVien",
        "MonThi",
        "PhongThi",
        "GiamThi",
        "CaThi",
        "CaThi_PhongThi",
        "DangKy",
        "LichThi",
        "LichThi_SinhVien",
        "LichThi_GiamThi",
    ]
    missing = [t for t in required if not _table_exists(cur, t)]
    if missing:
        raise RuntimeError(
            "Thiếu schema DB. Hãy chạy LichThi.sql để tạo bảng trước. "
            f"Thiếu: {', '.join(missing)}"
        )


def _fetch_existing_keys(cur: pyodbc.Cursor, sql: str) -> set[str]:
    cur.execute(sql)
    return {str(r[0]) for r in cur.fetchall()}


def _count(cur: pyodbc.Cursor, table: str) -> int:
    cur.execute(f"SELECT COUNT(*) FROM dbo.{table}")
    return int(cur.fetchone()[0])


def _chunks(items: list[tuple], chunk_size: int) -> Iterable[list[tuple]]:
    for i in range(0, len(items), chunk_size):
        yield items[i : i + chunk_size]


def _load_sql_seed_text() -> str:
    sql_path = Path(__file__).with_name("LichThi.sql")
    if not sql_path.exists():
        return ""
    return sql_path.read_text(encoding="utf-8")


def _extract_insert_values_block(sql_text: str, table: str) -> str:
    """Extracts the VALUES (...) block for a specific INSERT INTO dbo.<table> ... VALUES ...;

    Returns the raw text between VALUES and the ending semicolon.
    """

    if not sql_text:
        return ""

    needle = f"INSERT INTO dbo.{table}"
    start = sql_text.find(needle)
    if start < 0:
        return ""
    values_pos = sql_text.find("VALUES", start)
    if values_pos < 0:
        return ""
    values_pos = values_pos + len("VALUES")
    end = sql_text.find(";", values_pos)
    if end < 0:
        return ""
    return sql_text[values_pos:end]


def _parse_sql_values_tuples(values_block: str) -> list[list[object]]:
    """Parses a SQL Server VALUES block like: (N'a', 1, NULL), (N'b', 2, N'c')

    Designed specifically for the seed blocks in LichThi.sql.
    """

    def strip_line_comments(text: str) -> str:
        out: list[str] = []
        i = 0
        n = len(text)
        in_string = False
        while i < n:
            ch = text[i]
            if ch == "'":
                if in_string and i + 1 < n and text[i + 1] == "'":
                    out.append("''")
                    i += 2
                    continue
                in_string = not in_string
                out.append(ch)
                i += 1
                continue
            if not in_string and ch == "-" and i + 1 < n and text[i + 1] == "-":
                # skip until end of line
                while i < n and text[i] not in "\r\n":
                    i += 1
                continue
            out.append(ch)
            i += 1
        return "".join(out)

    values_block = strip_line_comments(values_block)

    tuples: list[list[object]] = []
    i = 0
    n = len(values_block)

    def skip_ws() -> None:
        nonlocal i
        while i < n and values_block[i].isspace():
            i += 1

    def parse_string() -> str:
        nonlocal i
        # assumes current char is '\''
        i += 1
        out_chars: list[str] = []
        while i < n:
            ch = values_block[i]
            if ch == "'":
                if i + 1 < n and values_block[i + 1] == "'":
                    out_chars.append("'")
                    i += 2
                    continue
                i += 1
                break
            out_chars.append(ch)
            i += 1
        return "".join(out_chars)

    def parse_value() -> object:
        nonlocal i
        skip_ws()
        if i >= n:
            return None

        # NVARCHAR literal: N'...'
        if values_block[i] in ("N", "n") and i + 1 < n and values_block[i + 1] == "'":
            i += 1
            return parse_string()
        if values_block[i] == "'":
            return parse_string()

        # NULL
        if values_block[i : i + 4].upper() == "NULL":
            i += 4
            return None

        # number token (int)
        j = i
        while j < n and values_block[j] not in ",)\r\n\t ":
            j += 1
        token = values_block[i:j].strip()
        i = j
        if token == "":
            return None
        try:
            return int(token)
        except ValueError:
            return token

    while i < n:
        skip_ws()
        if i >= n:
            break
        ch = values_block[i]
        if ch == "(":
            i += 1
            row: list[object] = []
            while i < n:
                skip_ws()
                if i < n and values_block[i] == ")":
                    i += 1
                    break
                row.append(parse_value())
                skip_ws()
                if i < n and values_block[i] == ",":
                    i += 1
                    continue
            tuples.append(row)
            skip_ws()
            if i < n and values_block[i] == ",":
                i += 1
            continue
        i += 1

    return tuples


def _load_sql_canonical_seed() -> dict[str, list[list[object]]]:
    sql_text = _load_sql_seed_text()
    if not sql_text:
        return {}

    out: dict[str, list[list[object]]] = {}
    for table in ("MonThi", "PhongThi", "GiamThi", "SinhVien"):
        block = _extract_insert_values_block(sql_text, table)
        if block:
            out[table] = _parse_sql_values_tuples(block)
    return out


def seed_sample_data(
    conn: pyodbc.Connection,
    *,
    reset: bool = False,
    # Defaults are chosen to closely match the seed dataset in LichThi.sql
    student_count: int = 240,
    course_count: int = 8,
) -> SeedResult:
    """Tạo dữ liệu mẫu đầy đủ để phục vụ chạy tối ưu.

    Tạo/cập nhật các bảng:
    - SinhVien, MonThi, PhongThi, CaThi, CaThi_PhongThi, DangKy

    Nếu reset=True:
    - Xoá lịch thi + đăng ký + danh mục mẫu trước khi tạo lại.

    Lưu ý: Hàm giả định schema đã tồn tại (đã chạy LichThi.sql).
    """

    if student_count <= 0:
        raise ValueError("student_count phải > 0")
    if course_count <= 0:
        raise ValueError("course_count phải > 0")

    cur = conn.cursor()
    _ensure_schema(cur)

    canonical = _load_sql_canonical_seed()

    result = SeedResult(reset=reset)

    if reset:
        # Delete in FK-safe order
        cur.execute("DELETE FROM dbo.LichThi_SinhVien")
        cur.execute("DELETE FROM dbo.LichThi_GiamThi")
        cur.execute("DELETE FROM dbo.LichThi")
        cur.execute("DELETE FROM dbo.CaThi_PhongThi")
        cur.execute("DELETE FROM dbo.DangKy")
        cur.execute("DELETE FROM dbo.CaThi")
        cur.execute("DELETE FROM dbo.PhongThi")
        cur.execute("DELETE FROM dbo.MonThi")
        # keep GiamThi optional; but safe to clear too for a clean sample
        if _table_exists(cur, "GiamThi"):
            cur.execute("DELETE FROM dbo.GiamThi")
        cur.execute("DELETE FROM dbo.SinhVien")

    # ---------- Seed canonical data from LichThi.sql (source of truth) ----------
    # Courses
    course_ids: list[str] = []
    if "MonThi" in canonical and canonical["MonThi"]:
        # canonical tuple order (7 cols): MaMon, TenMon, ThoiLuongPhut, HinhThucThi, DoKho, LoaiMon, GhiChu
        course_ids = [str(r[0]) for r in canonical["MonThi"]]

        existing_courses = _fetch_existing_keys(cur, "SELECT MaMon FROM dbo.MonThi") if not reset else set()
        to_insert = []
        to_update = []
        for r in canonical["MonThi"]:
            ma_mon = str(r[0])
            payload = (str(r[1]), int(r[2]), str(r[3]), r[4], str(r[5]) if r[5] is not None else None, r[6])
            if ma_mon in existing_courses:
                to_update.append((*payload, ma_mon))
            else:
                to_insert.append((ma_mon, *payload))

        if to_insert:
            cur.fast_executemany = True
            cur.executemany(
                """
                INSERT INTO dbo.MonThi (MaMon, TenMon, ThoiLuongPhut, HinhThucThi, DoKho, LoaiMon, GhiChu)
                VALUES (?, ?, ?, ?, ?, ?, ?)
                """,
                to_insert,
            )
            result.inserted_courses = len(to_insert)

        if to_update:
            cur.fast_executemany = True
            cur.executemany(
                """
                UPDATE dbo.MonThi
                SET TenMon = ?, ThoiLuongPhut = ?, HinhThucThi = ?, DoKho = ?, LoaiMon = ?, GhiChu = ?
                WHERE MaMon = ?
                """,
                to_update,
            )
    else:
        # Fallback: keep previous behavior when SQL seed is not available.
        sql_like_courses = [
            ("IT001", "Cơ sở dữ liệu", 90, "TracNghiem"),
            ("IT002", "Cấu trúc dữ liệu và giải thuật", 120, "TuLuan"),
            ("IT003", "Lập trình hướng đối tượng", 90, "TuLuan"),
            ("IT004", "Mạng máy tính", 90, "TracNghiem"),
            ("IT005", "Hệ điều hành", 120, "TuLuan"),
            ("IT006", "Lập trình Web", 90, "TuLuan"),
            ("IT007", "Toán rời rạc", 90, "TuLuan"),
            ("IT008", "Nhập môn Trí tuệ nhân tạo", 90, "VanDap"),
        ]

        extra_courses = []
        if course_count > len(sql_like_courses):
            for idx in range(len(sql_like_courses) + 1, course_count + 1):
                extra_courses.append((f"IT{idx:03d}", f"Môn tự chọn {idx:02d}", 90, "TuLuan"))

        courses = (sql_like_courses + extra_courses)[:course_count]
        course_ids = [c[0] for c in courses]

        course_rows = []
        existing_courses = _fetch_existing_keys(cur, "SELECT MaMon FROM dbo.MonThi") if not reset else set()
        for ma_mon, ten, tl, ht in courses:
            if ma_mon in existing_courses:
                continue
            course_rows.append((ma_mon, ten, int(tl), ht))

        if course_rows:
            cur.fast_executemany = True
            cur.executemany(
                """
                INSERT INTO dbo.MonThi (MaMon, TenMon, ThoiLuongPhut, HinhThucThi)
                VALUES (?, ?, ?, ?)
                """,
                course_rows,
            )
            result.inserted_courses = len(course_rows)

    # Rooms
    if "PhongThi" in canonical and canonical["PhongThi"]:
        existing_rooms = _fetch_existing_keys(cur, "SELECT MaPhong FROM dbo.PhongThi") if not reset else set()
        to_insert = []
        to_update = []
        for r in canonical["PhongThi"]:
            ma_phong = str(r[0])
            payload = (str(r[1]), int(r[2]), str(r[3]) if r[3] is not None else None, str(r[4]) if r[4] is not None else None, r[5])
            if ma_phong in existing_rooms:
                to_update.append((*payload, ma_phong))
            else:
                to_insert.append((ma_phong, *payload))

        if to_insert:
            cur.fast_executemany = True
            cur.executemany(
                """
                INSERT INTO dbo.PhongThi (MaPhong, TenPhong, SucChua, ToaNha, Tang, GhiChu)
                VALUES (?, ?, ?, ?, ?, ?)
                """,
                to_insert,
            )
            result.inserted_rooms = len(to_insert)

        if to_update:
            cur.fast_executemany = True
            cur.executemany(
                """
                UPDATE dbo.PhongThi
                SET TenPhong = ?, SucChua = ?, ToaNha = ?, Tang = ?, GhiChu = ?
                WHERE MaPhong = ?
                """,
                to_update,
            )
    else:
        rooms = [
            ("A101", "Phòng A101", 50),
            ("A102", "Phòng A102", 50),
            ("A103", "Phòng A103", 50),
            ("A104", "Phòng A104", 50),
            ("A105", "Phòng A105", 50),
            ("A106", "Phòng A106", 50),
            ("A201", "Phòng A201", 40),
            ("B201", "Phòng B201", 60),
            ("LAB1", "Phòng máy LAB1", 60),
            ("HALL1", "Hội trường 1", 80),
        ]

        existing_rooms = _fetch_existing_keys(cur, "SELECT MaPhong FROM dbo.PhongThi") if not reset else set()
        room_rows = []
        for ma_phong, ten_phong, suc_chua in rooms:
            if ma_phong in existing_rooms:
                continue
            room_rows.append((ma_phong, ten_phong, int(suc_chua)))

        if room_rows:
            cur.fast_executemany = True
            cur.executemany(
                """
                INSERT INTO dbo.PhongThi (MaPhong, TenPhong, SucChua)
                VALUES (?, ?, ?)
                """,
                room_rows,
            )
            result.inserted_rooms = len(room_rows)

    # Invigilators (GiamThi)
    if "GiamThi" in canonical and canonical["GiamThi"]:
        existing_gt = _fetch_existing_keys(cur, "SELECT MaGiamThi FROM dbo.GiamThi") if not reset else set()
        to_insert = []
        to_update = []
        for r in canonical["GiamThi"]:
            ma_gt = str(r[0])
            payload = (
                str(r[1]),
                str(r[2]) if r[2] is not None else None,
                str(r[3]) if r[3] is not None else None,
                str(r[4]) if r[4] is not None else None,
                str(r[5]) if r[5] is not None else None,
            )
            if ma_gt in existing_gt:
                to_update.append((*payload, ma_gt))
            else:
                to_insert.append((ma_gt, *payload))

        if to_insert:
            cur.fast_executemany = True
            cur.executemany(
                """
                INSERT INTO dbo.GiamThi (MaGiamThi, HoTen, DonVi, DienThoai, Email, TrangThai)
                VALUES (?, ?, ?, ?, ?, ?)
                """,
                to_insert,
            )
            result.inserted_invigilators = len(to_insert)

        if to_update:
            cur.fast_executemany = True
            cur.executemany(
                """
                UPDATE dbo.GiamThi
                SET HoTen = ?, DonVi = ?, DienThoai = ?, Email = ?, TrangThai = ?
                WHERE MaGiamThi = ?
                """,
                to_update,
            )

    # Students
    if "SinhVien" in canonical and canonical["SinhVien"]:
        existing_students = _fetch_existing_keys(cur, "SELECT MaSinhVien FROM dbo.SinhVien") if not reset else set()
        to_insert = []
        to_update = []
        for r in canonical["SinhVien"]:
            ma_sv = str(r[0])
            payload = (
                str(r[1]),
                str(r[2]) if r[2] is not None else None,
                str(r[3]) if r[3] is not None else None,
                str(r[4]) if r[4] is not None else None,
            )
            if ma_sv in existing_students:
                to_update.append((*payload, ma_sv))
            else:
                to_insert.append((ma_sv, *payload))

        if to_insert:
            cur.fast_executemany = True
            cur.executemany(
                """
                INSERT INTO dbo.SinhVien (MaSinhVien, HoTen, Lop, Khoa, TrangThai)
                VALUES (?, ?, ?, ?, ?)
                """,
                to_insert,
            )
            result.inserted_students = len(to_insert)

        if to_update:
            cur.fast_executemany = True
            cur.executemany(
                """
                UPDATE dbo.SinhVien
                SET HoTen = ?, Lop = ?, Khoa = ?, TrangThai = ?
                WHERE MaSinhVien = ?
                """,
                to_update,
            )
    else:
        # Fallback synthetic generation
        existing_students = _fetch_existing_keys(cur, "SELECT MaSinhVien FROM dbo.SinhVien") if not reset else set()

        last_names = ["Nguyễn", "Trần", "Lê", "Phạm", "Hoàng", "Vũ", "Bùi", "Đỗ", "Đặng", "Phan"]
        middle_names = ["Văn", "Thị", "Minh", "Quốc", "Gia", "Hồng", "Thu", "Thanh", "Đức", "Ngọc"]
        first_names = [
            "Anh",
            "Bảo",
            "Châu",
            "Dũng",
            "Hà",
            "Huy",
            "Khánh",
            "Linh",
            "Mai",
            "Nam",
            "Phúc",
            "Quân",
            "Sơn",
            "Trang",
            "Tuấn",
            "Vy",
            "Tâm",
            "Ngân",
            "Khoa",
            "Long",
            "Hưng",
            "Thảo",
            "My",
        ]

        def make_name(n: int) -> str:
            ln = last_names[n % len(last_names)]
            mn = middle_names[(n // 2) % len(middle_names)]
            fn = first_names[(n * 3) % len(first_names)]
            return f"{ln} {mn} {fn}"

        student_rows = []
        for i in range(1, student_count + 1):
            ma_sv = f"SV{i:03d}"
            if ma_sv in existing_students:
                continue
            ho_ten = make_name(i)
            lop = f"CTK{(40 + (i % 6))}"
            khoa = "Công nghệ thông tin"
            trang_thai = "DangHoc"
            student_rows.append((ma_sv, ho_ten, lop, khoa, trang_thai))

        if student_rows:
            cur.fast_executemany = True
            cur.executemany(
                """
                INSERT INTO dbo.SinhVien (MaSinhVien, HoTen, Lop, Khoa, TrangThai)
                VALUES (?, ?, ?, ?, ?)
                """,
                student_rows,
            )
            result.inserted_students = len(student_rows)

    # ---------- Seed exam slots (CaThi) (match dates/times in LichThi.sql) ----------
    # 2026-06-01 & 2026-06-02: 4 slots/day
    # 2026-06-03 .. 2026-06-12: 2 slots/day
    slot_specs: list[tuple[date, int, time, time, str]] = []

    def add_day_4(day: date) -> None:
        slot_specs.extend(
            [
                (day, 1, time(8, 0), time(9, 30), "Ca 1 sáng"),
                (day, 2, time(9, 45), time(11, 15), "Ca 2 sáng"),
                (day, 3, time(13, 0), time(14, 30), "Ca 1 chiều"),
                (day, 4, time(14, 45), time(16, 15), "Ca 2 chiều"),
            ]
        )

    def add_day_2(day: date) -> None:
        slot_specs.extend(
            [
                (day, 1, time(8, 0), time(9, 30), "Ca 1 sáng"),
                (day, 2, time(13, 0), time(14, 30), "Ca 2 chiều"),
            ]
        )

    add_day_4(date(2026, 6, 1))
    add_day_4(date(2026, 6, 2))
    for d in range(3, 13):
        add_day_2(date(2026, 6, d))

    existing_slot_pairs: set[tuple[str, int]] = set()
    if not reset:
        cur.execute("SELECT CONVERT(varchar(10), NgayThi, 23) AS Ngay, ThuTuTrongNgay FROM dbo.CaThi")
        existing_slot_pairs = {(str(r[0]), int(r[1])) for r in cur.fetchall()}

    slot_rows = []
    for ngay_thi, thu_tu, start_t, end_t, ghi_chu in slot_specs:
        day_str = ngay_thi.isoformat()
        if (day_str, thu_tu) in existing_slot_pairs:
            continue
        slot_rows.append((ngay_thi, thu_tu, start_t, end_t, ghi_chu))

    if slot_rows:
        cur.fast_executemany = True
        cur.executemany(
            """
            INSERT INTO dbo.CaThi (NgayThi, ThuTuTrongNgay, GioBatDau, GioKetThuc, GhiChu)
            VALUES (?, ?, ?, ?, ?)
            """,
            slot_rows,
        )
        result.inserted_slots = len(slot_rows)

    # Fetch slots we care about (June 2026)
    cur.execute(
        """
        SELECT MaCa, NgayThi, ThuTuTrongNgay
        FROM dbo.CaThi
        WHERE NgayThi >= '2026-06-01' AND NgayThi <= '2026-06-12'
        """
    )
    slots = [(int(r[0]), r[1], int(r[2])) for r in cur.fetchall()]

    # Fetch rooms list (all current rooms in table)
    cur.execute("SELECT MaPhong FROM dbo.PhongThi")
    all_room_ids = [str(r[0]) for r in cur.fetchall()]

    # ---------- Seed availability (CaThi_PhongThi) ----------
    existing_avail: set[tuple[int, str]] = set()
    if not reset:
        cur.execute("SELECT MaCa, MaPhong FROM dbo.CaThi_PhongThi")
        existing_avail = {(int(r[0]), str(r[1])) for r in cur.fetchall()}

    avail_rows = []
    for ma_ca, _, _ in slots:
        for ma_phong in all_room_ids:
            key = (ma_ca, ma_phong)
            if key in existing_avail:
                continue
            avail_rows.append((ma_ca, ma_phong, "SanSang"))

    if avail_rows:
        cur.fast_executemany = True
        # Chunk to avoid huge parameter payload
        for chunk in _chunks(avail_rows, 2000):
            cur.executemany(
                """
                INSERT INTO dbo.CaThi_PhongThi (MaCa, MaPhong, TrangThai)
                VALUES (?, ?, ?)
                """,
                chunk,
            )
        result.inserted_availability = len(avail_rows)

    # ---------- Seed registrations (DangKy) (match LichThi.sql distribution) ----------
    # If DangKy already has rows and not reset, keep it (avoid mixing datasets).
    if reset or _count(cur, "DangKy") == 0:
        # Distribution is designed to produce a realistic dataset and mirrors the SQL script:
        # - IT001: all students
        # - other courses: specific STT ranges

        def sv_id(stt: int) -> str:
            return f"SV{stt:03d}"

        max_stt = student_count
        reg_rows: list[tuple[str, str, date]] = []
        reg_date = date(2026, 5, 20)

        if "IT001" in course_ids:
            for stt in range(1, max_stt + 1):
                reg_rows.append((sv_id(stt), "IT001", reg_date))

        ranges = [
            ("IT003", 1, 45),
            ("IT002", 46, 100),
            ("IT004", 101, 145),
            ("IT005", 146, 195),
            ("IT006", 196, 240),
            ("IT007", 1, 40),
            ("IT008", 41, 80),
        ]

        for ma_mon, a, b in ranges:
            if ma_mon not in course_ids:
                continue
            start = max(1, min(a, max_stt))
            end = max(1, min(b, max_stt))
            if end < start:
                continue
            for stt in range(start, end + 1):
                reg_rows.append((sv_id(stt), ma_mon, reg_date))

        cur.fast_executemany = True
        for chunk in _chunks(reg_rows, 2000):
            cur.executemany(
                """
                INSERT INTO dbo.DangKy (MaSinhVien, MaMon, NgayDangKy)
                VALUES (?, ?, ?)
                """,
                chunk,
            )
        result.inserted_registrations = len(reg_rows)

    return result
