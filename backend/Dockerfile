FROM python:3.10-slim

WORKDIR /app

# Dependencies first so Docker caches them across code-only rebuilds.
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 8000
# --proxy-headers: trust Render's X-Forwarded-Proto so uploaded-image URLs
# come back as https://... instead of http://...
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--proxy-headers", "--forwarded-allow-ips=*"]
