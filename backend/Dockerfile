# ==============================================================================
# Stage 1: Dependency Builder
# ==============================================================================
FROM python:3.10-slim AS builder

WORKDIR /build

COPY backend/requirements.txt .
# Install production requirements plus explicitly added httpx and google-cloud-storage
# All dependencies provide pre-compiled manylinux wheels on PyPI (no build-essential needed)
RUN pip install --no-cache-dir --user -r requirements.txt httpx google-cloud-storage

# ==============================================================================
# Stage 2: Production Runtime
# ==============================================================================
FROM python:3.10-slim AS runner

WORKDIR /app

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PORT=8080 \
    PATH=/home/appuser/.local/bin:$PATH

# Create dedicated unprivileged non-root application user
RUN groupadd -r appgroup && useradd -r -g appgroup -u 1001 -m appuser

# Copy installed Python packages from builder stage
COPY --from=builder /root/.local /home/appuser/.local

# Copy application source code and packaged static catalog assets
COPY backend/app ./app
COPY public ./public

# Ensure upload directories exist and are owned by appuser
RUN mkdir -p /app/public/visits /app/public/products /app/public/uploads \
    && chown -R appuser:appgroup /app

USER appuser

EXPOSE 8080

# Cloud Run dynamic PORT binding via shell expansion
CMD ["sh", "-c", "uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8080} --proxy-headers --forwarded-allow-ips='*'"]
