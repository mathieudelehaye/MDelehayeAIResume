# ---- base image ----------------------------------------------------------
FROM python:3.11-slim

# ---- environment ---------------------------------------------------------
ENV PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

# ---- system dependencies ------------------------------------------------
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    curl && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

# ---- Python dependencies -------------------------------------------------
# Copy separately to leverage Docker layer cache
COPY requirements.txt ./
RUN pip install --upgrade pip && \
    pip install -r requirements.txt

# ---- copy source code ----------------------------------------------------
COPY . .

# ---- expose port & default command --------------------------------------
EXPOSE 8000
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "2"] 