-- Schema MSSQL cho bài toán lập lịch thi (CHỈ GIỮ BẢNG + CONSTRAINT/INDEX)

IF DB_ID(N'LichThi') IS NULL
BEGIN
    CREATE DATABASE [LichThi];
END
GO
USE [LichThi];
GO

-- Dọn bảng (khi cần reset)
IF OBJECT_ID(N'dbo.LichThi_SinhVien', N'U') IS NOT NULL DROP TABLE dbo.LichThi_SinhVien;
IF OBJECT_ID(N'dbo.LichThi_GiamThi', N'U') IS NOT NULL DROP TABLE dbo.LichThi_GiamThi;
IF OBJECT_ID(N'dbo.LichThi', N'U') IS NOT NULL DROP TABLE dbo.LichThi;
IF OBJECT_ID(N'dbo.CaThi_PhongThi', N'U') IS NOT NULL DROP TABLE dbo.CaThi_PhongThi;
IF OBJECT_ID(N'dbo.DangKy', N'U') IS NOT NULL DROP TABLE dbo.DangKy;
IF OBJECT_ID(N'dbo.CaThi', N'U') IS NOT NULL DROP TABLE dbo.CaThi;
IF OBJECT_ID(N'dbo.PhongThi', N'U') IS NOT NULL DROP TABLE dbo.PhongThi;
IF OBJECT_ID(N'dbo.MonThi', N'U') IS NOT NULL DROP TABLE dbo.MonThi;
IF OBJECT_ID(N'dbo.GiamThi', N'U') IS NOT NULL DROP TABLE dbo.GiamThi;
IF OBJECT_ID(N'dbo.SinhVien', N'U') IS NOT NULL DROP TABLE dbo.SinhVien;
GO

CREATE TABLE dbo.SinhVien (
    MaSinhVien NVARCHAR(20) NOT NULL PRIMARY KEY,
    HoTen NVARCHAR(100) NOT NULL,
    Lop NVARCHAR(50) NULL,
    Khoa NVARCHAR(100) NULL,
    TrangThai NVARCHAR(30) NOT NULL CONSTRAINT DF_SV_TrangThai DEFAULT(N'DangHoc')
);
GO

CREATE TABLE dbo.MonThi (
    MaMon NVARCHAR(20) NOT NULL PRIMARY KEY,
    TenMon NVARCHAR(200) NOT NULL,
    ThoiLuongPhut INT NOT NULL,
    HinhThucThi NVARCHAR(20) NOT NULL CONSTRAINT DF_MonThi_HinhThuc DEFAULT(N'TuLuan'),
    DoKho TINYINT NULL,
    LoaiMon NVARCHAR(50) NULL,
    GhiChu NVARCHAR(500) NULL
);
GO

ALTER TABLE dbo.MonThi
ADD CONSTRAINT CK_MonThi_HinhThucThi CHECK (HinhThucThi IN (N'TuLuan', N'TracNghiem', N'VanDap'));
GO

CREATE TABLE dbo.GiamThi (
    MaGiamThi NVARCHAR(20) NOT NULL PRIMARY KEY,
    HoTen NVARCHAR(100) NOT NULL,
    DonVi NVARCHAR(100) NULL,
    DienThoai NVARCHAR(30) NULL,
    Email NVARCHAR(120) NULL,
    TrangThai NVARCHAR(30) NOT NULL CONSTRAINT DF_GiamThi_TrangThai DEFAULT(N'DangLam')
);
GO

CREATE TABLE dbo.DangKy (
    MaSinhVien NVARCHAR(20) NOT NULL,
    MaMon NVARCHAR(20) NOT NULL,
    NgayDangKy DATE NULL,
    CONSTRAINT PK_DangKy PRIMARY KEY (MaSinhVien, MaMon),
    CONSTRAINT FK_DK_SV FOREIGN KEY (MaSinhVien) REFERENCES dbo.SinhVien(MaSinhVien) ON DELETE CASCADE,
    CONSTRAINT FK_DK_Mon FOREIGN KEY (MaMon) REFERENCES dbo.MonThi(MaMon) ON DELETE CASCADE
);
GO

CREATE TABLE dbo.PhongThi (
    MaPhong NVARCHAR(20) NOT NULL PRIMARY KEY,
    TenPhong NVARCHAR(100) NOT NULL,
    SucChua INT NOT NULL,
    ToaNha NVARCHAR(50) NULL,
    Tang NVARCHAR(10) NULL,
    GhiChu NVARCHAR(500) NULL
);
GO

CREATE TABLE dbo.CaThi (
    MaCa INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    NgayThi DATE NOT NULL,
    ThuTuTrongNgay INT NOT NULL, -- 1..4
    GioBatDau TIME(0) NOT NULL,
    GioKetThuc TIME(0) NOT NULL,
    ThoiLuongPhut AS (DATEDIFF(MINUTE, GioBatDau, GioKetThuc)) PERSISTED,
    GhiChu NVARCHAR(200) NULL,
    CONSTRAINT UQ_CaThi UNIQUE (NgayThi, ThuTuTrongNgay)
);
GO

ALTER TABLE dbo.CaThi
ADD CONSTRAINT CK_CaThi_ThuTuTrongNgay CHECK (ThuTuTrongNgay BETWEEN 1 AND 4);
GO

CREATE TABLE dbo.CaThi_PhongThi (
    MaCa INT NOT NULL,
    MaPhong NVARCHAR(20) NOT NULL,
    TrangThai NVARCHAR(20) NOT NULL CONSTRAINT DF_CaPhong_TrangThai DEFAULT(N'SanSang'),
    GhiChu NVARCHAR(200) NULL,
    CONSTRAINT PK_CaThi_PhongThi PRIMARY KEY (MaCa, MaPhong),
    CONSTRAINT FK_CaPhong_Ca FOREIGN KEY (MaCa) REFERENCES dbo.CaThi(MaCa) ON DELETE CASCADE,
    CONSTRAINT FK_CaPhong_Phong FOREIGN KEY (MaPhong) REFERENCES dbo.PhongThi(MaPhong)
);
GO

ALTER TABLE dbo.CaThi_PhongThi
ADD CONSTRAINT CK_CaPhong_TrangThai CHECK (TrangThai IN (N'SanSang', N'Khoa'));
GO

CREATE TABLE dbo.LichThi (
    MaLich INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    MaMon NVARCHAR(20) NOT NULL,
    MaCa INT NOT NULL,
    MaPhong NVARCHAR(20) NOT NULL,
    TrangThai NVARCHAR(20) NOT NULL CONSTRAINT DF_LichThi_TrangThai DEFAULT(N'Nhap'),
    ThoiGianTao DATETIME2(0) NOT NULL CONSTRAINT DF_LichThi_Tao DEFAULT(SYSDATETIME()),
    GhiChu NVARCHAR(500) NULL,
    CONSTRAINT FK_LT_Mon FOREIGN KEY (MaMon) REFERENCES dbo.MonThi(MaMon),
    CONSTRAINT FK_LT_Ca FOREIGN KEY (MaCa) REFERENCES dbo.CaThi(MaCa),
    CONSTRAINT FK_LT_Phong FOREIGN KEY (MaPhong) REFERENCES dbo.PhongThi(MaPhong),
    CONSTRAINT FK_LT_CaPhong FOREIGN KEY (MaCa, MaPhong) REFERENCES dbo.CaThi_PhongThi(MaCa, MaPhong),
    CONSTRAINT UQ_LT_Mon_Ca_Phong UNIQUE (MaMon, MaCa, MaPhong),
    CONSTRAINT UQ_LT_Phong_Ca UNIQUE (MaPhong, MaCa)
);
GO

ALTER TABLE dbo.LichThi
ADD CONSTRAINT CK_LichThi_TrangThai CHECK (TrangThai IN (N'Nhap', N'Chot'));
GO

CREATE TABLE dbo.LichThi_GiamThi (
    MaLich INT NOT NULL,
    ThuTu TINYINT NOT NULL, -- 1 hoặc 2
    MaGiamThi NVARCHAR(20) NOT NULL,
    CONSTRAINT PK_LT_GT PRIMARY KEY (MaLich, ThuTu),
    CONSTRAINT FK_LTGT_Lich FOREIGN KEY (MaLich) REFERENCES dbo.LichThi(MaLich) ON DELETE CASCADE,
    CONSTRAINT FK_LTGT_GiamThi FOREIGN KEY (MaGiamThi) REFERENCES dbo.GiamThi(MaGiamThi),
    CONSTRAINT CK_LTGT_ThuTu CHECK (ThuTu IN (1, 2)),
    CONSTRAINT UQ_LTGT_Lich_GiamThi UNIQUE (MaLich, MaGiamThi)
);
GO

CREATE TABLE dbo.LichThi_SinhVien (
    MaLich INT NOT NULL,
    MaSinhVien NVARCHAR(20) NOT NULL,
    CONSTRAINT PK_LT_SV PRIMARY KEY (MaLich, MaSinhVien),
    CONSTRAINT FK_LT_SV_Lich FOREIGN KEY (MaLich) REFERENCES dbo.LichThi(MaLich) ON DELETE CASCADE,
    CONSTRAINT FK_LT_SV_SV FOREIGN KEY (MaSinhVien) REFERENCES dbo.SinhVien(MaSinhVien)
);
GO

CREATE INDEX IX_DangKy_MaMon ON dbo.DangKy(MaMon);
CREATE INDEX IX_CaThi_Ngay ON dbo.CaThi(NgayThi);
GO

-- Comment sửa lại cho đúng thực tế hiện tại
-- Lưu ý: Chưa có trigger tự động phân công giám thị.
-- Nếu cần, có thể thêm trigger hoặc stored procedure riêng để gán giám thị khi chốt lịch.

-------------------------------------------------------------------------------
-- DỮ LIỆU MẪU (đúng thứ tự FK, phù hợp constraint)
-------------------------------------------------------------------------------
SET NOCOUNT ON;
SET DATEFORMAT ymd;
GO

BEGIN TRY
    BEGIN TRAN;

    -- 1) Danh mục: Môn thi
    INSERT INTO dbo.MonThi (MaMon, TenMon, ThoiLuongPhut, HinhThucThi, DoKho, LoaiMon, GhiChu)
    VALUES
        (N'IT001', N'Cơ sở dữ liệu', 90,  N'TracNghiem', 3, N'CoSo',   NULL),
        (N'IT002', N'Cấu trúc dữ liệu và giải thuật', 120, N'TuLuan',   4, N'ChuyenNganh', NULL),
        (N'IT003', N'Lập trình hướng đối tượng', 90,  N'TuLuan',   3, N'CoSo',   NULL),
        (N'IT004', N'Mạng máy tính', 90,  N'TracNghiem', 3, N'CoSo',   NULL),
        (N'IT005', N'Hệ điều hành', 120, N'TuLuan',   4, N'ChuyenNganh', NULL),
        (N'IT006', N'Lập trình Web', 90,  N'TuLuan',   3, N'ChuyenNganh', NULL),
        (N'IT007', N'Toán rời rạc', 90,  N'TuLuan',   2, N'CoSo',   NULL),
        (N'IT008', N'Nhập môn Trí tuệ nhân tạo', 90, N'VanDap',   3, N'TuChon', NULL);

    -- 2) Danh mục: Phòng thi
    INSERT INTO dbo.PhongThi (MaPhong, TenPhong, SucChua, ToaNha, Tang, GhiChu)
    VALUES
        -- Tăng sức chứa để đảm bảo mỗi phòng của ca đông >30 SV
        (N'A101',  N'Phòng A101', 50, N'A', N'1', NULL),
        (N'A102',  N'Phòng A102', 50, N'A', N'1', NULL),
        (N'A103',  N'Phòng A103', 50, N'A', N'1', NULL),
        (N'A104',  N'Phòng A104', 50, N'A', N'1', NULL),
        (N'A105',  N'Phòng A105', 50, N'A', N'1', NULL),
        (N'A106',  N'Phòng A106', 50, N'A', N'1', NULL),
        (N'A201',  N'Phòng A201', 40, N'A', N'2', NULL),
        (N'B201',  N'Phòng B201', 60, N'B', N'2', NULL),
        (N'LAB1',  N'Phòng máy LAB1', 60, N'A', N'3', N'Phòng máy tính'),
        (N'HALL1', N'Hội trường 1', 80, N'C', N'1', N'Ưu tiên thi đông');

    -- 3) Danh mục: Giám thị
    INSERT INTO dbo.GiamThi (MaGiamThi, HoTen, DonVi, DienThoai, Email, TrangThai)
    VALUES
        (N'GT01', N'Nguyễn Văn An',  N'Khoa CNTT', N'0901000001', N'an.nguyen@univ.edu',  N'DangLam'),
        (N'GT02', N'Trần Thị Bình',  N'Khoa CNTT', N'0901000002', N'binh.tran@univ.edu',  N'DangLam'),
        (N'GT03', N'Lê Văn Cường',   N'Khoa CNTT', N'0901000003', N'cuong.le@univ.edu',   N'DangLam'),
        (N'GT04', N'Phạm Thị Dung',  N'Khoa CNTT', N'0901000004', N'dung.pham@univ.edu',  N'DangLam'),
        (N'GT05', N'Hoàng Văn Em',   N'Phòng ĐT',  N'0901000005', N'em.hoang@univ.edu',   N'DangLam'),
        (N'GT06', N'Vũ Thị Giang',   N'Phòng ĐT',  N'0901000006', N'giang.vu@univ.edu',   N'DangLam'),
        (N'GT07', N'Đỗ Văn Hùng',    N'Khoa Toán', N'0901000007', N'hung.do@univ.edu',    N'DangLam'),
        (N'GT08', N'Bùi Thị Khánh',  N'Khoa Toán', N'0901000008', N'khanh.bui@univ.edu',  N'DangLam'),
        (N'GT09', N'Đặng Văn Long',  N'Khoa CNTT', N'0901000009', N'long.dang@univ.edu',  N'DangLam'),
        (N'GT10', N'Phan Thị Mai',   N'Khoa CNTT', N'0901000010', N'mai.phan@univ.edu',   N'DangLam'),
        (N'GT11', N'Nguyễn Thị Hồng', N'Khoa CNTT', N'0901000011', N'hong.nguyen@univ.edu', N'DangLam'),
        (N'GT12', N'Trần Văn Khang',  N'Khoa CNTT', N'0901000012', N'khang.tran@univ.edu',  N'DangLam'),
        (N'GT13', N'Lê Thị Mộng Thảo',N'Khoa CNTT', N'0901000013', N'thao.le@univ.edu',     N'DangLam'),
        (N'GT14', N'Phạm Văn Quân',   N'Khoa CNTT', N'0901000014', N'quan.pham@univ.edu',   N'DangLam'),
        (N'GT15', N'Hoàng Thị Yến',   N'Khoa CNTT', N'0901000015', N'yen.hoang@univ.edu',   N'DangLam'),
        (N'GT16', N'Vũ Văn Tín',      N'Khoa CNTT', N'0901000016', N'tin.vu@univ.edu',      N'DangLam'),
        (N'GT17', N'Đỗ Thị Thanh Hà', N'Khoa CNTT', N'0901000017', N'ha.do@univ.edu',       N'DangLam'),
        (N'GT18', N'Bùi Văn Duy',     N'Khoa CNTT', N'0901000018', N'duy.bui@univ.edu',     N'DangLam'),
        (N'GT19', N'Đặng Thị Ngọc Linh',N'Khoa CNTT', N'0901000019', N'linh.dang@univ.edu', N'DangLam'),
        (N'GT20', N'Phan Văn Phúc',   N'Khoa CNTT', N'0901000020', N'phuc.phan@univ.edu',   N'DangLam');

    -- 4) Danh mục: Sinh viên
    -- Tăng số lượng sinh viên (KHÔNG dùng vòng lặp): 240 SV tên/TT giống người thật
    INSERT INTO dbo.SinhVien (MaSinhVien, HoTen, Lop, Khoa, TrangThai)
    VALUES
        -- CTK42 (1-60)
        (N'SV001', N'Nguyễn Minh Anh',        N'CTK42', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV002', N'Trần Đức Bảo',           N'CTK42', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV003', N'Lê Thu Cúc',             N'CTK42', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV004', N'Phạm Quốc Dũng',         N'CTK42', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV005', N'Hoàng Gia Hân',          N'CTK42', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV006', N'Vũ Nhật Huy',            N'CTK42', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV007', N'Bùi Thị Linh',           N'CTK42', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV008', N'Đỗ Quang Minh',          N'CTK42', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV009', N'Phan Thị Ngọc',          N'CTK42', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV010', N'Đặng Văn Phúc',          N'CTK42', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV011', N'Nguyễn Thị Quỳnh',       N'CTK42', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV012', N'Trần Gia Sơn',           N'CTK42', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV013', N'Lê Thanh Tâm',           N'CTK42', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV014', N'Phạm Thảo Uyên',         N'CTK42', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV015', N'Hoàng Đức Việt',         N'CTK42', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV016', N'Vũ Thị Xuân',            N'CTK42', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV017', N'Bùi Văn Yên',            N'CTK42', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV018', N'Đỗ Thị Ánh',             N'CTK42', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV019', N'Phan Minh Châu',         N'CTK42', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV020', N'Đặng Thị Diệp',          N'CTK42', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV021', N'Nguyễn Quốc Giáp',       N'CTK42', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV022', N'Trần Thị Hoa',           N'CTK42', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV023', N'Lê Văn Khôi',            N'CTK42', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV024', N'Phạm Thị Lan',           N'CTK42', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV025', N'Hoàng Minh Khoa',        N'CTK42', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV026', N'Vũ Thảo My',             N'CTK42', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV027', N'Bùi Nhật Nam',           N'CTK42', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV028', N'Đỗ Thị Ngọc Mai',        N'CTK42', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV029', N'Đặng Minh Quang',        N'CTK42', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV030', N'Phan Hoài Thương',       N'CTK42', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV031', N'Nguyễn Thành Đạt',       N'CTK42', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV032', N'Trần Thị Bích Ngọc',     N'CTK42', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV033', N'Lê Hoàng Phương',        N'CTK42', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV034', N'Phạm Đức Huy',           N'CTK42', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV035', N'Hoàng Thị Thanh Trúc',   N'CTK42', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV036', N'Vũ Đình Tùng',           N'CTK42', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV037', N'Bùi Gia Bảo',            N'CTK42', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV038', N'Đỗ Thị Khánh Ly',        N'CTK42', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV039', N'Đặng Quốc Thái',         N'CTK42', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV040', N'Phan Thế Anh',           N'CTK42', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV041', N'Nguyễn Thị Hà My',       N'CTK42', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV042', N'Trần Minh Tuấn',         N'CTK42', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV043', N'Lê Thị Thùy Dương',      N'CTK42', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV044', N'Phạm Hoàng Long',        N'CTK42', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV045', N'Hoàng Ngọc Anh',         N'CTK42', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV046', N'Vũ Thị Như Ý',           N'CTK42', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV047', N'Bùi Văn Phúc Khang',     N'CTK42', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV048', N'Đỗ Đức Duy',             N'CTK42', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV049', N'Đặng Thị Ngọc Hân',      N'CTK42', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV050', N'Phan Văn Hiếu',          N'CTK42', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV051', N'Nguyễn Quang Huy',       N'CTK42', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV052', N'Trần Thị Kim Oanh',      N'CTK42', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV053', N'Lê Minh Tài',            N'CTK42', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV054', N'Phạm Thị Tú Anh',        N'CTK42', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV055', N'Hoàng Văn Hào',          N'CTK42', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV056', N'Vũ Ngọc Diễm',           N'CTK42', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV057', N'Bùi Hải Đăng',           N'CTK42', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV058', N'Đỗ Thị Thanh Ngân',      N'CTK42', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV059', N'Đặng Hoàng Nam',         N'CTK42', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV060', N'Phan Khánh An',          N'CTK42', N'Công nghệ thông tin', N'DangHoc'),
        -- CTK43 (61-120)
        (N'SV061', N'Ngô Thế Bảo',            N'CTK43', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV062', N'Trương Thị Bảo Trâm',    N'CTK43', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV063', N'Huỳnh Văn Cảnh',         N'CTK43', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV064', N'Võ Thị Diễm Quỳnh',      N'CTK43', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV065', N'Dương Minh Đức',         N'CTK43', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV066', N'Đinh Thị Hạnh',          N'CTK43', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV067', N'Cao Văn Hưng',           N'CTK43', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV068', N'Mai Thị Khả Vy',         N'CTK43', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV069', N'Tạ Quốc Khánh',          N'CTK43', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV070', N'Tôn Thị Lệ Thu',         N'CTK43', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV071', N'Lý Minh Khang',          N'CTK43', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV072', N'Châu Thị Minh Tâm',      N'CTK43', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV073', N'Triệu Quang Vinh',       N'CTK43', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV074', N'Lâm Thị Tuyết Mai',      N'CTK43', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV075', N'Thái Văn Phát',          N'CTK43', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV076', N'Đoàn Thị Yến Nhi',       N'CTK43', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV077', N'Kiều Minh Hoàng',        N'CTK43', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV078', N'Đặng Thị Bảo Ngọc',      N'CTK43', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV079', N'Phạm Gia Khiêm',         N'CTK43', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV080', N'Nguyễn Thị Thanh Tâm',   N'CTK43', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV081', N'Trần Quốc Bảo',          N'CTK43', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV082', N'Lê Thị Mỹ Linh',         N'CTK43', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV083', N'Hoàng Văn Kiệt',         N'CTK43', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV084', N'Vũ Thị Hải Yến',         N'CTK43', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV085', N'Bùi Quang Hào',          N'CTK43', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV086', N'Đỗ Thị Thu Hà',          N'CTK43', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV087', N'Đặng Minh Hưng',         N'CTK43', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV088', N'Phan Thị Bích Phương',   N'CTK43', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV089', N'Nguyễn Thanh Hậu',       N'CTK43', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV090', N'Trần Thị Thảo Nhi',      N'CTK43', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV091', N'Lê Đức Trí',             N'CTK43', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV092', N'Phạm Thị Ngọc Ánh',      N'CTK43', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV093', N'Hoàng Quốc Khánh',       N'CTK43', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV094', N'Vũ Minh Trang',          N'CTK43', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV095', N'Bùi Văn Tuấn',           N'CTK43', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV096', N'Đỗ Ngọc Thảo',           N'CTK43', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV097', N'Đặng Thị Tuyết Nhung',   N'CTK43', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV098', N'Phan Văn Tường',         N'CTK43', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV099', N'Nguyễn Hữu Phước',       N'CTK43', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV100', N'Trần Thị Mai Anh',       N'CTK43', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV101', N'Lê Văn Hòa',             N'CTK43', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV102', N'Phạm Thị Thùy Trang',    N'CTK43', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV103', N'Hoàng Minh Trường',      N'CTK43', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV104', N'Vũ Thị Thanh Vân',       N'CTK43', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV105', N'Bùi Ngọc Khôi',          N'CTK43', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV106', N'Đỗ Thị Thuỳ Linh',       N'CTK43', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV107', N'Đặng Văn Thành',         N'CTK43', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV108', N'Phan Thị Hồng Nhung',    N'CTK43', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV109', N'Nguyễn Nhật Tân',        N'CTK43', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV110', N'Trần Ngọc Bích',         N'CTK43', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV111', N'Lê Quốc Trung',          N'CTK43', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV112', N'Phạm Thị Thanh Thảo',    N'CTK43', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV113', N'Hoàng Văn Thịnh',        N'CTK43', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV114', N'Vũ Thị Kim Chi',         N'CTK43', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV115', N'Bùi Minh Tín',           N'CTK43', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV116', N'Đỗ Thị Ngọc Hương',      N'CTK43', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV117', N'Đặng Văn Vũ',            N'CTK43', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV118', N'Phan Thị Minh Nguyệt',   N'CTK43', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV119', N'Nguyễn Văn Quân',        N'CTK43', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV120', N'Trần Thị Bảo Châu',      N'CTK43', N'Công nghệ thông tin', N'DangHoc'),
        -- CTK44 (121-180)
        (N'SV121', N'Lê Minh Khoa',           N'CTK44', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV122', N'Phạm Thị Thanh Mai',     N'CTK44', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV123', N'Hoàng Quốc Huy',         N'CTK44', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV124', N'Vũ Thị Khánh Hòa',       N'CTK44', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV125', N'Bùi Văn Hoàng',          N'CTK44', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV126', N'Đỗ Thị Thanh Tâm',       N'CTK44', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV127', N'Đặng Minh Phương',       N'CTK44', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV128', N'Phan Văn Duy',           N'CTK44', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV129', N'Nguyễn Thị Nhã Phương',  N'CTK44', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV130', N'Trần Văn Minh',          N'CTK44', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV131', N'Lê Thị Thùy Linh',       N'CTK44', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV132', N'Phạm Quốc Thịnh',        N'CTK44', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV133', N'Hoàng Thị Bích Ngọc',    N'CTK44', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV134', N'Vũ Văn Quang',           N'CTK44', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV135', N'Bùi Thị Ngọc Mai',       N'CTK44', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV136', N'Đỗ Minh Đức',            N'CTK44', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV137', N'Đặng Thị Hồng Vân',      N'CTK44', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV138', N'Phan Quốc Bảo',          N'CTK44', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV139', N'Nguyễn Văn Tuấn Anh',    N'CTK44', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV140', N'Trần Thị Thu Uyên',      N'CTK44', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV141', N'Lê Văn Thành',           N'CTK44', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV142', N'Phạm Thị Như Quỳnh',     N'CTK44', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV143', N'Hoàng Minh Nhật',        N'CTK44', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV144', N'Vũ Thị Thanh Nga',       N'CTK44', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV145', N'Bùi Văn Đức',            N'CTK44', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV146', N'Đỗ Thị Bảo Trân',        N'CTK44', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV147', N'Đặng Minh Tùng',         N'CTK44', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV148', N'Phan Thị Mỹ Duyên',      N'CTK44', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV149', N'Nguyễn Quốc Việt',       N'CTK44', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV150', N'Trần Thị Thanh Huyền',   N'CTK44', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV151', N'Lê Quang Huy',           N'CTK44', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV152', N'Phạm Ngọc Hà',           N'CTK44', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV153', N'Hoàng Văn Hậu',          N'CTK44', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV154', N'Vũ Thị Phương Thảo',     N'CTK44', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV155', N'Bùi Minh Sơn',           N'CTK44', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV156', N'Đỗ Thị Thanh Vân',       N'CTK44', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV157', N'Đặng Quốc Duy',          N'CTK44', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV158', N'Phan Thị Hồng Nhung',    N'CTK44', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV159', N'Nguyễn Văn Khánh',       N'CTK44', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV160', N'Trần Thị Ngọc Anh',      N'CTK44', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV161', N'Lê Văn Dũng',            N'CTK44', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV162', N'Phạm Thị Thuỳ Dương',    N'CTK44', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV163', N'Hoàng Quốc Cường',       N'CTK44', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV164', N'Vũ Thị Mỹ Linh',         N'CTK44', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV165', N'Bùi Văn Trí',            N'CTK44', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV166', N'Đỗ Thị Thanh Trà',       N'CTK44', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV167', N'Đặng Minh Quân',         N'CTK44', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV168', N'Phan Văn Trung',         N'CTK44', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV169', N'Nguyễn Thị Mai Phương',  N'CTK44', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV170', N'Trần Văn Hòa',           N'CTK44', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV171', N'Lê Thị Bích Phương',     N'CTK44', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV172', N'Phạm Quốc Thái',         N'CTK44', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV173', N'Hoàng Thị Thanh Tuyền',  N'CTK44', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV174', N'Vũ Văn Tài',             N'CTK44', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV175', N'Bùi Thị Thu Hà',         N'CTK44', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV176', N'Đỗ Minh Khôi',           N'CTK44', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV177', N'Đặng Thị Ngọc Trâm',     N'CTK44', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV178', N'Phan Văn Tùng',          N'CTK44', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV179', N'Nguyễn Minh Tân',        N'CTK44', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV180', N'Trần Thị Kim Ngân',      N'CTK44', N'Công nghệ thông tin', N'DangHoc'),
        -- CTK45 (181-240)
        (N'SV181', N'Lê Quốc Huy',            N'CTK45', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV182', N'Phạm Thị Hồng Hạnh',     N'CTK45', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV183', N'Hoàng Văn Khánh',        N'CTK45', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV184', N'Vũ Thị Thuỳ Linh',       N'CTK45', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV185', N'Bùi Minh Quang',         N'CTK45', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV186', N'Đỗ Thị Minh Châu',       N'CTK45', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV187', N'Đặng Văn Kiên',          N'CTK45', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV188', N'Phan Thị Thu Trang',     N'CTK45', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV189', N'Nguyễn Văn Thành',       N'CTK45', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV190', N'Trần Thị Khánh Vy',      N'CTK45', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV191', N'Lê Minh Tuấn',           N'CTK45', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV192', N'Phạm Thị Ngọc Diệp',     N'CTK45', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV193', N'Hoàng Quốc Thắng',       N'CTK45', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV194', N'Vũ Thị Thanh Thủy',      N'CTK45', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV195', N'Bùi Văn Đạt',            N'CTK45', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV196', N'Đỗ Thị Diệu Linh',       N'CTK45', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV197', N'Đặng Minh Hải',          N'CTK45', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV198', N'Phan Thị Mai Hương',     N'CTK45', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV199', N'Nguyễn Văn Phong',       N'CTK45', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV200', N'Trần Thị Mỹ Duyên',      N'CTK45', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV201', N'Lê Quốc Duy',            N'CTK45', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV202', N'Phạm Thị Hồng Ngọc',     N'CTK45', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV203', N'Hoàng Minh Trí',         N'CTK45', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV204', N'Vũ Thị Thu Hằng',        N'CTK45', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV205', N'Bùi Văn Khôi',           N'CTK45', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV206', N'Đỗ Thị Như Ý',           N'CTK45', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV207', N'Đặng Văn Tài',           N'CTK45', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV208', N'Phan Thị Thanh Trúc',    N'CTK45', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV209', N'Nguyễn Minh Hòa',        N'CTK45', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV210', N'Trần Thị Bích Thảo',     N'CTK45', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV211', N'Lê Văn Quang',           N'CTK45', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV212', N'Phạm Thị Ngọc Hân',      N'CTK45', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV213', N'Hoàng Văn Hùng',         N'CTK45', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV214', N'Vũ Thị Minh Tâm',        N'CTK45', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV215', N'Bùi Văn Sơn',            N'CTK45', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV216', N'Đỗ Thị Thảo My',         N'CTK45', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV217', N'Đặng Minh Phúc',         N'CTK45', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV218', N'Phan Thị Thanh Nhàn',    N'CTK45', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV219', N'Nguyễn Văn Khải',        N'CTK45', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV220', N'Trần Thị Mai Chi',       N'CTK45', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV221', N'Lê Minh Hải',            N'CTK45', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV222', N'Phạm Thị Kim Ngọc',      N'CTK45', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV223', N'Hoàng Văn Khoa',         N'CTK45', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV224', N'Vũ Thị Bảo Ngọc',        N'CTK45', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV225', N'Bùi Minh Thành',         N'CTK45', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV226', N'Đỗ Thị Thu Trang',       N'CTK45', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV227', N'Đặng Văn Duy',           N'CTK45', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV228', N'Phan Thị Ngọc Mai',      N'CTK45', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV229', N'Nguyễn Quốc Tín',        N'CTK45', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV230', N'Trần Thị Thanh Hằng',    N'CTK45', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV231', N'Lê Văn Thắng',           N'CTK45', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV232', N'Phạm Thị Hồng Vân',      N'CTK45', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV233', N'Hoàng Minh Dũng',        N'CTK45', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV234', N'Vũ Thị Ngọc Ánh',        N'CTK45', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV235', N'Bùi Văn Thành',          N'CTK45', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV236', N'Đỗ Thị Thanh Tâm',       N'CTK45', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV237', N'Đặng Minh Khánh',        N'CTK45', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV238', N'Phan Văn Hưng',          N'CTK45', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV239', N'Nguyễn Thị Thuỳ Dung',   N'CTK45', N'Công nghệ thông tin', N'DangHoc'),
        (N'SV240', N'Trần Văn Phát',          N'CTK45', N'Công nghệ thông tin', N'DangHoc');

    -- 5) Ca thi (8 ca: 2 ngày x 4 ca)
    DECLARE @Ca TABLE (MaCa INT NOT NULL, NgayThi DATE NOT NULL, ThuTuTrongNgay INT NOT NULL);
    INSERT INTO dbo.CaThi (NgayThi, ThuTuTrongNgay, GioBatDau, GioKetThuc, GhiChu)
    OUTPUT inserted.MaCa, inserted.NgayThi, inserted.ThuTuTrongNgay INTO @Ca(MaCa, NgayThi, ThuTuTrongNgay)
    VALUES
                ('2026-06-01', 1, '08:00', '09:30', N'Ca 1 sáng'),
                ('2026-06-01', 2, '09:45', '11:15', N'Ca 2 sáng'),
                ('2026-06-01', 3, '13:00', '14:30', N'Ca 1 chiều'),
                ('2026-06-01', 4, '14:45', '16:15', N'Ca 2 chiều'),
                ('2026-06-02', 1, '08:00', '09:30', N'Ca 1 sáng'),
                ('2026-06-02', 2, '09:45', '11:15', N'Ca 2 sáng'),
                ('2026-06-02', 3, '13:00', '14:30', N'Ca 1 chiều'),
                ('2026-06-02', 4, '14:45', '16:15', N'Ca 2 chiều'),

                -- Thêm nhiều ngày thi để đáp ứng ràng buộc: mỗi SV cách nhau >= 3 ngày (preset ưu tiên SV)
                ('2026-06-03', 1, '08:00', '09:30', N'Ca 1 sáng'),
                ('2026-06-03', 2, '13:00', '14:30', N'Ca 2 chiều'),
                ('2026-06-04', 1, '08:00', '09:30', N'Ca 1 sáng'),
                ('2026-06-04', 2, '13:00', '14:30', N'Ca 2 chiều'),
                ('2026-06-05', 1, '08:00', '09:30', N'Ca 1 sáng'),
                ('2026-06-05', 2, '13:00', '14:30', N'Ca 2 chiều'),
                ('2026-06-06', 1, '08:00', '09:30', N'Ca 1 sáng'),
                ('2026-06-06', 2, '13:00', '14:30', N'Ca 2 chiều'),
                ('2026-06-07', 1, '08:00', '09:30', N'Ca 1 sáng'),
                ('2026-06-07', 2, '13:00', '14:30', N'Ca 2 chiều'),
                ('2026-06-08', 1, '08:00', '09:30', N'Ca 1 sáng'),
                ('2026-06-08', 2, '13:00', '14:30', N'Ca 2 chiều'),
                ('2026-06-09', 1, '08:00', '09:30', N'Ca 1 sáng'),
                ('2026-06-09', 2, '13:00', '14:30', N'Ca 2 chiều'),
                ('2026-06-10', 1, '08:00', '09:30', N'Ca 1 sáng'),
                ('2026-06-10', 2, '13:00', '14:30', N'Ca 2 chiều'),
                ('2026-06-11', 1, '08:00', '09:30', N'Ca 1 sáng'),
                ('2026-06-11', 2, '13:00', '14:30', N'Ca 2 chiều'),
                ('2026-06-12', 1, '08:00', '09:30', N'Ca 1 sáng'),
                ('2026-06-12', 2, '13:00', '14:30', N'Ca 2 chiều');

        -- Nếu bạn đã chạy seed trước đó: chạy lại script sẽ thêm ca mới.
        -- Đoạn UPDATE dưới đây giúp "chuẩn hoá" giờ thi về khung 08:00–17:00 cho các ngày seed.
        UPDATE dbo.CaThi
        SET
            GioBatDau = CASE ThuTuTrongNgay
                WHEN 1 THEN '08:00'
                WHEN 2 THEN '09:45'
                WHEN 3 THEN '13:00'
                WHEN 4 THEN '14:45'
                ELSE GioBatDau
            END,
            GioKetThuc = CASE ThuTuTrongNgay
                WHEN 1 THEN '09:30'
                WHEN 2 THEN '11:15'
                WHEN 3 THEN '14:30'
                WHEN 4 THEN '16:15'
                ELSE GioKetThuc
            END
        WHERE NgayThi IN ('2026-06-01', '2026-06-02')
            AND ThuTuTrongNgay IN (1, 2, 3, 4);

    -- 6) Bật tất cả phòng cho tất cả ca (phòng sẵn sàng theo ca)
    INSERT INTO dbo.CaThi_PhongThi (MaCa, MaPhong, TrangThai, GhiChu)
    SELECT c.MaCa, p.MaPhong, N'SanSang', NULL
    FROM dbo.CaThi c
    CROSS JOIN dbo.PhongThi p;

    -- 7) Đăng ký môn của sinh viên (mẫu, không trùng PK)
    ;WITH SV AS (
        SELECT
            MaSinhVien,
            CAST(SUBSTRING(MaSinhVien, 3, 10) AS INT) AS STT
        FROM dbo.SinhVien
    )
    -- Môn đông: IT001 (tất cả 240 SV)
    INSERT INTO dbo.DangKy (MaSinhVien, MaMon, NgayDangKy)
    SELECT sv.MaSinhVien, N'IT001', '2026-05-20'
    FROM SV sv;

    -- Các môn còn lại: chia nhóm để không vượt sức chứa phòng seed
    ;WITH SV AS (
        SELECT MaSinhVien, CAST(SUBSTRING(MaSinhVien, 3, 10) AS INT) AS STT
        FROM dbo.SinhVien
    )
    INSERT INTO dbo.DangKy (MaSinhVien, MaMon, NgayDangKy)
    SELECT MaSinhVien, N'IT003', '2026-05-20'
    FROM SV
    WHERE STT BETWEEN 1 AND 45;

    ;WITH SV AS (
        SELECT MaSinhVien, CAST(SUBSTRING(MaSinhVien, 3, 10) AS INT) AS STT
        FROM dbo.SinhVien
    )
    INSERT INTO dbo.DangKy (MaSinhVien, MaMon, NgayDangKy)
    SELECT MaSinhVien, N'IT002', '2026-05-20'
    FROM SV
    WHERE STT BETWEEN 46 AND 100; -- 55 SV

    ;WITH SV AS (
        SELECT MaSinhVien, CAST(SUBSTRING(MaSinhVien, 3, 10) AS INT) AS STT
        FROM dbo.SinhVien
    )
    INSERT INTO dbo.DangKy (MaSinhVien, MaMon, NgayDangKy)
    SELECT MaSinhVien, N'IT004', '2026-05-20'
    FROM SV
    WHERE STT BETWEEN 101 AND 145; -- 45 SV

    ;WITH SV AS (
        SELECT MaSinhVien, CAST(SUBSTRING(MaSinhVien, 3, 10) AS INT) AS STT
        FROM dbo.SinhVien
    )
    INSERT INTO dbo.DangKy (MaSinhVien, MaMon, NgayDangKy)
    SELECT MaSinhVien, N'IT005', '2026-05-20'
    FROM SV
    WHERE STT BETWEEN 146 AND 195; -- 50 SV

    ;WITH SV AS (
        SELECT MaSinhVien, CAST(SUBSTRING(MaSinhVien, 3, 10) AS INT) AS STT
        FROM dbo.SinhVien
    )
    INSERT INTO dbo.DangKy (MaSinhVien, MaMon, NgayDangKy)
    SELECT MaSinhVien, N'IT006', '2026-05-20'
    FROM SV
    WHERE STT BETWEEN 196 AND 240; -- 45 SV

    ;WITH SV AS (
        SELECT MaSinhVien, CAST(SUBSTRING(MaSinhVien, 3, 10) AS INT) AS STT
        FROM dbo.SinhVien
    )
    INSERT INTO dbo.DangKy (MaSinhVien, MaMon, NgayDangKy)
    SELECT MaSinhVien, N'IT007', '2026-05-20'
    FROM SV
    WHERE STT BETWEEN 1 AND 40;

    ;WITH SV AS (
        SELECT MaSinhVien, CAST(SUBSTRING(MaSinhVien, 3, 10) AS INT) AS STT
        FROM dbo.SinhVien
    )
    INSERT INTO dbo.DangKy (MaSinhVien, MaMon, NgayDangKy)
    SELECT MaSinhVien, N'IT008', '2026-05-20'
    FROM SV
    WHERE STT BETWEEN 41 AND 80;

    -- 8) Lịch thi
    -- Ghi chú: Có thể tổ chức nhiều phòng cho cùng 1 môn trong cùng 1 ca (chia danh sách SV theo phòng).
    DECLARE @c_0601_1 INT = (SELECT MaCa FROM @Ca WHERE NgayThi = '2026-06-01' AND ThuTuTrongNgay = 1);
    DECLARE @c_0601_2 INT = (SELECT MaCa FROM @Ca WHERE NgayThi = '2026-06-01' AND ThuTuTrongNgay = 2);
    DECLARE @c_0601_3 INT = (SELECT MaCa FROM @Ca WHERE NgayThi = '2026-06-01' AND ThuTuTrongNgay = 3);
    DECLARE @c_0601_4 INT = (SELECT MaCa FROM @Ca WHERE NgayThi = '2026-06-01' AND ThuTuTrongNgay = 4);
    DECLARE @c_0602_1 INT = (SELECT MaCa FROM @Ca WHERE NgayThi = '2026-06-02' AND ThuTuTrongNgay = 1);
    DECLARE @c_0602_2 INT = (SELECT MaCa FROM @Ca WHERE NgayThi = '2026-06-02' AND ThuTuTrongNgay = 2);
    DECLARE @c_0602_3 INT = (SELECT MaCa FROM @Ca WHERE NgayThi = '2026-06-02' AND ThuTuTrongNgay = 3);
    DECLARE @c_0602_4 INT = (SELECT MaCa FROM @Ca WHERE NgayThi = '2026-06-02' AND ThuTuTrongNgay = 4);

    DECLARE @Lich TABLE (MaLich INT NOT NULL, MaMon NVARCHAR(20) NOT NULL, MaCa INT NOT NULL, MaPhong NVARCHAR(20) NOT NULL);

    INSERT INTO dbo.LichThi (MaMon, MaCa, MaPhong, TrangThai, GhiChu)
    OUTPUT inserted.MaLich, inserted.MaMon, inserted.MaCa, inserted.MaPhong INTO @Lich(MaLich, MaMon, MaCa, MaPhong)
    VALUES
        -- IT001 (Trắc nghiệm) tổ chức 1 ca ở NHIỀU PHÒNG (>5 phòng), mỗi phòng >30 SV
        (N'IT001', @c_0601_1, N'A101',  N'Chot', N'Kỳ thi cuối kỳ (phòng 1)'),
        (N'IT001', @c_0601_1, N'A102',  N'Chot', N'Kỳ thi cuối kỳ (phòng 2)'),
        (N'IT001', @c_0601_1, N'A103',  N'Chot', N'Kỳ thi cuối kỳ (phòng 3)'),
        (N'IT001', @c_0601_1, N'A104',  N'Chot', N'Kỳ thi cuối kỳ (phòng 4)'),
        (N'IT001', @c_0601_1, N'A105',  N'Chot', N'Kỳ thi cuối kỳ (phòng 5)'),
        (N'IT001', @c_0601_1, N'A106',  N'Chot', N'Kỳ thi cuối kỳ (phòng 6)'),
        (N'IT003', @c_0601_2, N'A102',  N'Chot', N'Kỳ thi cuối kỳ'),
        (N'IT002', @c_0601_3, N'B201',  N'Nhap', N'Thời lượng 120 phút'),
        (N'IT007', @c_0601_4, N'A201',  N'Nhap', NULL),
        (N'IT004', @c_0602_1, N'A101',  N'Nhap', NULL),
        (N'IT006', @c_0602_2, N'LAB1',  N'Nhap', N'Thi trên máy'),
        (N'IT005', @c_0602_3, N'B201',  N'Nhap', N'Thời lượng 120 phút'),
        (N'IT008', @c_0602_4, N'HALL1', N'Nhap', N'Vấn đáp theo danh sách');

    -- 9) Phân công giám thị (mỗi PHÒNG/CA đúng 2 giám thị)
    -- Chọn theo vòng (round-robin) để các phòng trong cùng ca không nhất thiết trùng giám thị.
    DECLARE @GT TABLE (Idx INT IDENTITY(1,1) NOT NULL, MaGiamThi NVARCHAR(20) NOT NULL);
    INSERT INTO @GT (MaGiamThi)
    VALUES
        (N'GT01'), (N'GT02'), (N'GT03'), (N'GT04'), (N'GT05'), (N'GT06'), (N'GT07'), (N'GT08'), (N'GT09'), (N'GT10'),
        (N'GT11'), (N'GT12'), (N'GT13'), (N'GT14'), (N'GT15'), (N'GT16'), (N'GT17'), (N'GT18'), (N'GT19'), (N'GT20');

    ;WITH L AS (
        SELECT
            MaLich,
            ROW_NUMBER() OVER (ORDER BY MaCa, MaPhong, MaMon, MaLich) AS RN,
            (SELECT COUNT(*) FROM @GT) AS GTCount
        FROM @Lich
    )
    INSERT INTO dbo.LichThi_GiamThi (MaLich, ThuTu, MaGiamThi)
    SELECT
        l.MaLich,
        v.ThuTu,
        g.MaGiamThi
    FROM L l
    CROSS APPLY (
        VALUES
            (CAST(1 AS TINYINT), ((l.RN - 1) % l.GTCount) + 1),
            (CAST(2 AS TINYINT), ((l.RN) % l.GTCount) + 1)
    ) AS v(ThuTu, PickIdx)
    JOIN @GT g
      ON g.Idx = v.PickIdx;

    -- 10) Danh sách sinh viên theo lịch
    -- Nếu 1 môn có nhiều phòng trong cùng ca: chia danh sách SV đều theo phòng.
    ;WITH LichByMon AS (
        SELECT
            l.MaLich,
            l.MaMon,
            ROW_NUMBER() OVER (PARTITION BY l.MaMon ORDER BY l.MaPhong, l.MaLich) AS LichIndex,
            COUNT(*) OVER (PARTITION BY l.MaMon) AS LichCount
        FROM @Lich l
    ),
    DkRank AS (
        SELECT
            dk.MaMon,
            dk.MaSinhVien,
            ROW_NUMBER() OVER (PARTITION BY dk.MaMon ORDER BY dk.MaSinhVien) AS RN
        FROM dbo.DangKy dk
    )
    INSERT INTO dbo.LichThi_SinhVien (MaLich, MaSinhVien)
    SELECT lbm.MaLich, dr.MaSinhVien
    FROM DkRank dr
    JOIN LichByMon lbm
      ON lbm.MaMon = dr.MaMon
    WHERE ((dr.RN - 1) % lbm.LichCount) + 1 = lbm.LichIndex;

    COMMIT;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    THROW;
END CATCH;
GO