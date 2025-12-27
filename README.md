# github-issues-agent

```bash
 uv python pin 3.12
```

Bước 2: Chạy lại từ đầu theo đúng chuẩn (Best Practice)
Sau khi đã dọn dẹp, bạn hãy bắt đầu lại theo thứ tự này:

Khởi tạo lại môi trường và cài đặt thư viện: Dựa trên file pyproject.toml có sẵn, bạn chạy:

```bash
uv sync
```

Lệnh này sẽ tạo lại thư mục .venv và file uv.lock.

Thiết lập lại cấu hình Python: Đảm bảo dự án dùng đúng bản 3.12 như bạn mong muốn:

```bash
uv python pin 3.12
```

Cấu hình biến môi trường: Dựa trên file env.example có sẵn, bạn hãy tạo file mới:

```bash
cp env.example .env.dev
```

Sau đó, hãy mở file .env.dev và điền các API Key của bạn vào.

Khởi tạo lại Database: Sử dụng Alembic để tạo lại các bảng issues và comments:

```bash
uv run alembic upgrade head
```
Chạy thử Agent ở chế độ Development: Sử dụng file cấu hình langgraph.json:

```bash
uv run langgraph dev --env .env.dev
```
