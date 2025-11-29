# syntax=docker/dockerfile:1

FROM python:3.11-slim

# Create non-root user
RUN useradd -m appuser

# Set workdir
WORKDIR /app

# Install runtime deps and create a venv (optional)
RUN apt-get update && apt-get install -y --no-install-recommends \
      build-essential curl ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# Copy only requirements first for better caching
COPY requirements.txt /app/
RUN pip install --no-cache-dir -r requirements.txt

# Copy the app
COPY . /app

# Environment
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1

# Expose Flask default port
EXPOSE 5000

# Drop privileges
USER appuser

# Start the app
CMD ["python", "app.py"]
