# Hospital Inventory RL - Docker Deployment Guide

**Industry-standard, production-ready deployment for custom Gym/RL environment**

This project implements a reinforcement learning solution for hospital inventory management using Docker for reproducible training, inference, and API serving.

---

## 📁 Project Structure

```
perishable-ml/
├── hospital_env/          # Custom Gymnasium environment
│   ├── __init__.py
│   └── HospitalEnv.py    # Hospital inventory environment
│
├── train/                 # Training module
│   ├── train.py          # Training script with env var support
│   └── config.yaml       # Configuration file
│
├── inference/             # Inference module
│   ├── predict.py        # Batch inference script
│   └── api.py            # FastAPI REST API server
│
├── models/                # Saved models (volume mounted)
│   └── dqn_inventory.zip
│
├── tb_logs/              # TensorBoard logs
│
├── requirements.txt      # Python dependencies
├── Dockerfile           # Docker image definition
├── docker-compose.yml   # Multi-service orchestration
└── README.md           # This file
```

---

## 🚀 Quick Start

### 1. Build Docker Image

```powershell
docker build -t custom-rl-env .
```

### 2. Train Model

```powershell
docker run --rm -v ${PWD}/models:/app/models custom-rl-env
```

### 3. Serve API

```powershell
docker run -p 8000:8000 -v ${PWD}/models:/app/models custom-rl-env uvicorn inference.api:app --host 0.0.0.0 --port 8000
```

### 4. Test API

```powershell
curl -X POST http://localhost:8000/predict -H "Content-Type: application/json" -d '{\"inventory\": [10, 8, 6, 4, 2, 1, 0], \"pipeline\": [5, 0, 10, 0, 0, 0], \"forecast\": 15.5}'
```

---

## ⚡ Complete Workflow

### **Method A: Train inside Docker (Clean & Reproducible)**

Train with default parameters:
```powershell
docker run --rm -v ${PWD}/models:/app/models custom-rl-env python train/train.py
```

Train with custom hyperparameters:
```powershell
docker run --rm `
  -e TIMESTEPS=50000 `
  -e LEARNING_RATE=5e-4 `
  -e BUFFER_SIZE=100000 `
  -e BATCH_SIZE=64 `
  -v ${PWD}/models:/app/models `
  custom-rl-env python train/train.py
```

### **Method B: Train with GPU (NVIDIA Runtime)**

```powershell
docker run --gpus all --rm `
  -v ${PWD}/models:/app/models `
  custom-rl-env python train/train.py
```

### **Method C: Retrain Existing Model**

Simply run the training command again - it will overwrite the existing model:
```powershell
docker run --rm -v ${PWD}/models:/app/models custom-rl-env python train/train.py
```

---

## 🎯 Run Inference

### **Batch Inference (Full Episode)**

```powershell
docker run --rm -v ${PWD}/models:/app/models custom-rl-env python inference/predict.py
```

### **Interactive Inference (API Server)**

Start the API server:
```powershell
docker run -p 8000:8000 -v ${PWD}/models:/app/models custom-rl-env uvicorn inference.api:app --host 0.0.0.0 --port 8000
```

Access interactive docs at: http://localhost:8000/docs

---

## 🌐 API Endpoints

### **1. Health Check**
```powershell
curl http://localhost:8000/health
```

### **2. Single Prediction**
```powershell
curl -X POST http://localhost:8000/predict `
  -H "Content-Type: application/json" `
  -d '{
    "inventory": [10.0, 8.0, 6.0, 4.0, 2.0, 1.0, 0.0],
    "pipeline": [5.0, 0.0, 10.0, 0.0, 0.0, 0.0],
    "forecast": 15.5
  }'
```

Response:
```json
{
  "action": 12,
  "observation": {
    "inventory": [10.0, 8.0, 6.0, 4.0, 2.0, 1.0, 0.0],
    "pipeline": [5.0, 0.0, 10.0, 0.0, 0.0, 0.0],
    "forecast": 15.5
  }
}
```

### **3. Batch Prediction**
```powershell
curl -X POST http://localhost:8000/batch_predict `
  -H "Content-Type: application/json" `
  -d '[
    {"inventory": [10, 8, 6, 4, 2, 1, 0], "pipeline": [5, 0, 10, 0, 0, 0], "forecast": 15.5},
    {"inventory": [5, 4, 3, 2, 1, 0, 0], "pipeline": [0, 0, 8, 0, 0, 0], "forecast": 12.0}
  ]'
```

---

## 🐳 Docker Compose (Full System)

### Start All Services

```powershell
docker-compose up -d
```

This starts:
- **Trainer**: Trains the model
- **API**: Serves predictions on port 8000
- **TensorBoard**: Monitoring on port 6006

### Individual Services

```powershell
# Train only
docker-compose up trainer

# Run API only
docker-compose up api

# View TensorBoard
docker-compose up tensorboard
```

### Stop All Services

```powershell
docker-compose down
```

### View Logs

```powershell
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f api
```

---

## 📊 Monitor Training (TensorBoard)

### Method 1: Docker Compose
```powershell
docker-compose up tensorboard
```
Access at: http://localhost:6006

### Method 2: Standalone Container
```powershell
docker run -p 6006:6006 -v ${PWD}/tb_logs:/logs tensorflow/tensorflow tensorboard --logdir=/logs --host=0.0.0.0
```

---

## 🔧 Development Workflow

### 1. Local Development (Without Docker)

Install dependencies:
```powershell
pip install -r requirements.txt
```

Train locally:
```powershell
python train/train.py
```

Run inference:
```powershell
python inference/predict.py
```

Start API:
```powershell
uvicorn inference.api:app --reload
```

### 2. Build and Test Docker Image

```powershell
# Build
docker build -t custom-rl-env .

# Test training
docker run --rm -v ${PWD}/models:/app/models custom-rl-env

# Test API
docker run -d -p 8000:8000 -v ${PWD}/models:/app/models custom-rl-env uvicorn inference.api:app --host 0.0.0.0 --port 8000
```

---

## 📦 Environment Variables

Configure training via environment variables:

| Variable | Description | Default |
|----------|-------------|---------|
| `TIMESTEPS` | Total training steps | 20000 |
| `LEARNING_RATE` | Learning rate | 1e-3 |
| `BUFFER_SIZE` | Replay buffer size | 50000 |
| `BATCH_SIZE` | Batch size | 32 |

Example:
```powershell
docker run --rm `
  -e TIMESTEPS=100000 `
  -e LEARNING_RATE=3e-4 `
  -v ${PWD}/models:/app/models `
  custom-rl-env python train/train.py
```

---

## 🎓 Model Information

- **Algorithm**: DQN (Deep Q-Network)
- **Policy**: MLP (Multi-Layer Perceptron)
- **Environment**: Custom Hospital Inventory Environment
- **State Space**: 14 dimensions (7 inventory ages + 6 pipeline + 1 forecast)
- **Action Space**: Discrete (0-50 units to order)

---

## 🛠️ Troubleshooting

### Model Not Found
Ensure you've trained a model first:
```powershell
docker run --rm -v ${PWD}/models:/app/models custom-rl-env python train/train.py
```

### Port Already in Use
```powershell
# Find and stop process using port 8000
netstat -ano | findstr :8000
taskkill /PID <PID> /F

# Or use a different port
docker run -p 8001:8000 -v ${PWD}/models:/app/models custom-rl-env uvicorn inference.api:app --host 0.0.0.0 --port 8000
```

### Volume Mounting Issues (Windows)
Use absolute paths:
```powershell
docker run --rm -v "E:/Dev/docker/perishable-ml/models:/app/models" custom-rl-env
```

---

## 📝 Production Deployment Checklist

- [ ] Build Docker image
- [ ] Train model with production hyperparameters
- [ ] Test inference locally
- [ ] Test API endpoints
- [ ] Set up monitoring (TensorBoard)
- [ ] Configure environment variables
- [ ] Set up persistent volumes
- [ ] Deploy with docker-compose or Kubernetes
- [ ] Configure reverse proxy (nginx)
- [ ] Set up logging and alerting

---

## 🔄 CI/CD Integration

### GitHub Actions Example

```yaml
name: Train and Deploy RL Model

on:
  push:
    branches: [main]

jobs:
  train:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      
      - name: Build Docker image
        run: docker build -t custom-rl-env .
      
      - name: Train model
        run: |
          docker run --rm \
            -v $(pwd)/models:/app/models \
            custom-rl-env python train/train.py
      
      - name: Upload model artifact
        uses: actions/upload-artifact@v2
        with:
          name: trained-model
          path: models/
```

---

## 📚 Additional Resources

- [Stable-Baselines3 Documentation](https://stable-baselines3.readthedocs.io/)
- [Gymnasium Documentation](https://gymnasium.farama.org/)
- [FastAPI Documentation](https://fastapi.tiangolo.com/)
- [Docker Documentation](https://docs.docker.com/)

---

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test with Docker
5. Submit a pull request

---

## 📄 License

MIT License - see LICENSE file for details

---

## 👥 Support

For issues and questions:
- Open an issue on GitHub
- Check existing documentation
- Review TensorBoard logs for training issues

---

**Built with ❤️ using industry-standard RL deployment practices**
