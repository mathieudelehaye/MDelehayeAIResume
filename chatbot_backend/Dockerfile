# ---- base image ----------------------------------------------------------
FROM python:3.11-slim

WORKDIR /app

# Install system dependencies required for psycopg and other packages
RUN apt-get update && apt-get install -y \
    gcc \
    python3-dev \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements first for better caching
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Expose the port the app runs on (HuggingFace Spaces uses 7860)
EXPOSE 7860

# Command to run the application
CMD ["python", "app.py"] 