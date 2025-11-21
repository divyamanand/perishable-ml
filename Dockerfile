# Multi-stage Docker build for Hospital Inventory RL Environment
FROM python:3.10-slim

# System dependencies for Prophet and scientific computing
RUN apt-get update && apt-get install -y \
    python3-dev \
    build-essential \
    git \
    cmake \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy requirements first for better caching
COPY requirements.txt /app/

# Install Python dependencies
RUN pip install --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# Copy entire project
COPY . /app

# Create models and logs directories if they don't exist
RUN mkdir -p /app/models /app/tb_logs

# Environment variables for configuration
ENV TIMESTEPS=20000 \
    LEARNING_RATE=1e-3 \
    BUFFER_SIZE=50000 \
    BATCH_SIZE=32

# Expose port for API server
EXPOSE 8000

# Default command: run training
CMD ["python", "train/train.py"]
