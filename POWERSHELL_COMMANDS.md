# PowerShell Quick Reference Guide
# Hospital Inventory RL - Docker Commands for Windows

# ============================================
# BUILDING
# ============================================

# Build the Docker image
docker build -t custom-rl-env .

# Build with no cache (clean build)
docker build --no-cache -t custom-rl-env .


# ============================================
# TRAINING
# ============================================

# Train with default settings
docker run --rm -v ${PWD}/models:/app/models custom-rl-env

# Train with custom hyperparameters
docker run --rm `
  -e TIMESTEPS=50000 `
  -e LEARNING_RATE=5e-4 `
  -v ${PWD}/models:/app/models `
  custom-rl-env python train/train.py

# Train and save logs
docker run --rm `
  -v ${PWD}/models:/app/models `
  -v ${PWD}/tb_logs:/app/tb_logs `
  custom-rl-env python train/train.py


# ============================================
# INFERENCE
# ============================================

# Run batch inference
docker run --rm -v ${PWD}/models:/app/models custom-rl-env python inference/predict.py

# Run inference API server
docker run -p 8000:8000 -v ${PWD}/models:/app/models custom-rl-env uvicorn inference.api:app --host 0.0.0.0 --port 8000

# Run API in background (detached)
docker run -d --name hospital-rl-api -p 8000:8000 -v ${PWD}/models:/app/models custom-rl-env uvicorn inference.api:app --host 0.0.0.0 --port 8000


# ============================================
# API TESTING
# ============================================

# Health check
curl http://localhost:8000/health

# Single prediction
curl -X POST http://localhost:8000/predict `
  -H "Content-Type: application/json" `
  -d '{\"inventory\": [10, 8, 6, 4, 2, 1, 0], \"pipeline\": [5, 0, 10, 0, 0, 0], \"forecast\": 15.5}'

# Open API docs in browser
Start-Process "http://localhost:8000/docs"


# ============================================
# DOCKER COMPOSE
# ============================================

# Start all services
docker-compose up -d

# Start specific service
docker-compose up api

# View logs
docker-compose logs -f

# View specific service logs
docker-compose logs -f api

# Stop all services
docker-compose down

# Restart specific service
docker-compose restart api


# ============================================
# TENSORBOARD
# ============================================

# Run TensorBoard standalone
docker run -p 6006:6006 -v ${PWD}/tb_logs:/logs tensorflow/tensorflow tensorboard --logdir=/logs --host=0.0.0.0

# Open TensorBoard in browser
Start-Process "http://localhost:6006"


# ============================================
# CONTAINER MANAGEMENT
# ============================================

# List running containers
docker ps

# List all containers (including stopped)
docker ps -a

# Stop a running container
docker stop hospital-rl-api

# Remove a container
docker rm hospital-rl-api

# View container logs
docker logs hospital-rl-api

# Execute command in running container
docker exec -it hospital-rl-api bash


# ============================================
# CLEANUP
# ============================================

# Remove all stopped containers
docker container prune

# Remove unused images
docker image prune

# Remove all unused resources
docker system prune -a

# Remove specific image
docker rmi custom-rl-env


# ============================================
# DEBUGGING
# ============================================

# Run container interactively
docker run -it --rm -v ${PWD}/models:/app/models custom-rl-env bash

# Check container environment
docker run --rm custom-rl-env env

# Inspect image
docker inspect custom-rl-env

# View image layers
docker history custom-rl-env


# ============================================
# DEVELOPMENT
# ============================================

# Build and run immediately
docker build -t custom-rl-env . ; docker run --rm -v ${PWD}/models:/app/models custom-rl-env

# Watch logs in real-time
docker logs -f hospital-rl-api

# Copy files from container
docker cp hospital-rl-api:/app/models/dqn_inventory.zip ./models/

# Copy files to container
docker cp ./models/dqn_inventory.zip hospital-rl-api:/app/models/


# ============================================
# ADVANCED
# ============================================

# Run with GPU support (requires NVIDIA Docker)
docker run --gpus all --rm -v ${PWD}/models:/app/models custom-rl-env python train/train.py

# Set memory limits
docker run --rm --memory="2g" -v ${PWD}/models:/app/models custom-rl-env python train/train.py

# Run on specific network
docker run --rm --network=host -v ${PWD}/models:/app/models custom-rl-env python train/train.py

# Mount as read-only
docker run --rm -v ${PWD}/models:/app/models:ro custom-rl-env python inference/predict.py
