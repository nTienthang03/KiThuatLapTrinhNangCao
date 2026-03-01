# Tối ưu lịch thi (MSSQL + Python + HTML)

## 1) Chuẩn bị database
- Mở SQL Server Management Studio (SSMS)
- Chạy script [LichThi.sql](LichThi.sql) để tạo DB `LichThi` + seed dữ liệu

## 2) Cấu hình kết nối
- Tạo file `.env` (copy từ `.env.example`) và chỉnh lại nếu cần.

Ví dụ:
```dotenv
DB_SERVER=DESKTOP-OT7SJ1I\MSSQLSERVERDEV
DB_DATABASE=LichThi
DB_USER=sa
DB_PASSWORD=123
```

## 3) Cài thư viện Python
```bash
python -m venv .venv
.venv\\Scripts\\activate
pip install -r requirements.txt
```

> Lưu ý: `pyodbc` cần ODBC Driver cho SQL Server (thường là **ODBC Driver 18 for SQL Server**).

## 4) Chạy web
```bash
python app.py
```
- Mở: http://127.0.0.1:5000
- Bấm **Tối ưu** để tạo lại lịch thi từ bảng `DangKy`.

## Thuật toán
Greedy đơn giản:
- Xếp môn có nhiều SV trước
- Chọn ca sớm nhất thoả không xung đột SV và đủ sức chứa phòng rảnh
- Chia SV theo nhiều phòng trong cùng ca






