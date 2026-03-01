import os
from dataclasses import dataclass

import pyodbc
from dotenv import load_dotenv


@dataclass(frozen=True)
class DbConfig:
    server: str
    database: str
    user: str
    password: str
    port: int = 1433
    odbc_driver: str = "ODBC Driver 18 for SQL Server"
    encrypt: str = "yes"  # yes/no
    trust_server_certificate: str = "yes"  # yes/no


def load_config() -> DbConfig:
    load_dotenv(override=False)

    server = os.getenv("DB_SERVER", r"DESKTOP-OT7SJ1I\MSSQLSERVERDEV")
    # Nhiều người copy từ ví dụ dùng "\\"; chuẩn hoá về "\" để ODBC luôn hiểu đúng.
    server = server.replace("\\\\", "\\")
    database = os.getenv("DB_DATABASE", "LichThi")
    user = os.getenv("DB_USER", "sa")
    password = os.getenv("DB_PASSWORD", "123")
    port = int(os.getenv("DB_PORT", "1433"))
    odbc_driver = os.getenv("ODBC_DRIVER", "ODBC Driver 18 for SQL Server")

    # Có môi trường không bật Encrypt mặc định; để an toàn ta để Encrypt=yes + TrustServerCertificate=yes
    encrypt = os.getenv("DB_ENCRYPT", "yes")
    trust = os.getenv("DB_TRUST_SERVER_CERTIFICATE", "yes")

    return DbConfig(
        server=server,
        database=database,
        user=user,
        password=password,
        port=port,
        odbc_driver=odbc_driver,
        encrypt=encrypt,
        trust_server_certificate=trust,
    )


def _build_conn_strings(cfg: DbConfig) -> list[str]:
    base = (
        f"DRIVER={{{cfg.odbc_driver}}};"
        f"DATABASE={cfg.database};"
        f"UID={cfg.user};PWD={cfg.password};"
        f"Encrypt={cfg.encrypt};TrustServerCertificate={cfg.trust_server_certificate};"
        "Connection Timeout=30;"
    )

    # Named instance (DESKTOP\\INSTANCE) đôi khi không hợp khi kèm ",port".
    # Nên thử vài biến thể để tăng khả năng kết nối.
    return [
        f"SERVER={cfg.server},{cfg.port};" + base,
        f"SERVER={cfg.server};" + base,
    ]


def get_connection() -> pyodbc.Connection:
    cfg = load_config()
    last_error: Exception | None = None

    for conn_str in _build_conn_strings(cfg):
        try:
            # autocommit=False để tự quản transaction
            return pyodbc.connect(conn_str, autocommit=False)
        except pyodbc.Error as exc:
            last_error = exc

    assert last_error is not None
    raise last_error
