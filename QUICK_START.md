# 🚀 Quick Start Guide - Hospital Inventory RL

## ⚡ Fastest Way to Get Started

### **Step 1: Build the Image** (One-time setup)
```powershell
docker build -t custom-rl-env .
```

### **Step 2: Train Your Model**
```powershell
docker run --rm -v ${PWD}/models:/app/models custom-rl-env
```
⏱️ Takes ~2-5 minutes depending on your hardware

### **Step 3: Run the API**
```powershell
docker run -p 8000:8000 -v ${PWD}/models:/app/models custom-rl-env uvicorn inference.api:app --host 0.0.0.0 --port 8000
```

### **Step 4: Test It**
Open your browser: http://localhost:8000/docs

Or use curl:
```powershell
curl http://localhost:8000/health
```

---

## 📊 Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                     DOCKER ECOSYSTEM                             │
│                                                                   │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │
│  │   TRAINER    │  │     API      │  │ TENSORBOARD  │          │
│  │              │  │              │  │              │          │
│  │ train/       │  │ inference/   │  │ Monitoring   │          │
│  │ train.py     │  │ api.py       │  │ Port: 6006   │          │
│  │              │  │ Port: 8000   │  │              │          │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘          │
│         │                 │                  │                   │
│         └────────┬────────┴──────────────────┘                   │
│                  │                                                │
│         ┌────────▼────────┐                                      │
│         │  SHARED VOLUMES │                                      │
│         │                 │                                      │
│         │  📁 models/     │  ← Trained models persist here      │
│         │  📁 tb_logs/    │  ← TensorBoard logs                 │
│         └─────────────────┘                                      │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                     CUSTOM ENVIRONMENT                           │
│                                                                   │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  hospital_env/HospitalEnv.py                             │   │
│  │                                                            │   │
│  │  State Space (14D):                                       │   │
│  │    • Inventory by age [7 values]                          │   │
│  │    • Order pipeline [6 values]                            │   │
│  │    • Demand forecast [1 value]                            │   │
│  │                                                            │   │
│  │  Action Space: Discrete(51) → Order 0-50 units           │   │
│  │                                                            │   │
│  │  Reward: -cost (holding + waste + shortage)              │   │
│  └──────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

---

## 🔄 Complete Workflow

### **Development Cycle**

```
1. CODE → 2. BUILD → 3. TRAIN → 4. INFERENCE → 5. SERVE → 6. RETRAIN
   ↑                                                              ↓
   └──────────────────────────────────────────────────────────────┘
```

**Detailed Steps:**

```
1️⃣ CODE
   └─ Edit environment, training, or inference code

2️⃣ BUILD
   └─ docker build -t custom-rl-env .

3️⃣ TRAIN
   └─ docker run --rm -v ${PWD}/models:/app/models custom-rl-env

4️⃣ INFERENCE (Test)
   └─ docker run --rm -v ${PWD}/models:/app/models custom-rl-env python inference/predict.py

5️⃣ SERVE (Production)
   └─ docker run -p 8000:8000 -v ${PWD}/models:/app/models custom-rl-env uvicorn inference.api:app --host 0.0.0.0 --port 8000

6️⃣ RETRAIN (with new hyperparameters)
   └─ docker run --rm -e TIMESTEPS=50000 -v ${PWD}/models:/app/models custom-rl-env python train/train.py
```

---

## 🎯 Common Use Cases

### **Use Case 1: Quick Experimentation**
```powershell
# Train with different hyperparameters
docker run --rm -e TIMESTEPS=10000 -e LEARNING_RATE=5e-4 -v ${PWD}/models:/app/models custom-rl-env python train/train.py
```

### **Use Case 2: Production Deployment**
```powershell
# Use docker-compose for full stack
docker-compose up -d

# API available at: http://localhost:8000
# TensorBoard at: http://localhost:6006
```

### **Use Case 3: CI/CD Pipeline**
```powershell
# 1. Build in CI
docker build -t custom-rl-env .

# 2. Train
docker run --rm -v ${PWD}/models:/app/models custom-rl-env

# 3. Test
docker run --rm -v ${PWD}/models:/app/models custom-rl-env python inference/predict.py

# 4. Deploy API
docker run -d -p 8000:8000 -v ${PWD}/models:/app/models custom-rl-env uvicorn inference.api:app --host 0.0.0.0 --port 8000
```

---

## 📦 Project Files Overview

```
perishable-ml/
│
├── 🐳 Docker Files
│   ├── Dockerfile              # Image definition
│   ├── docker-compose.yml      # Multi-service orchestration
│   └── .dockerignore           # Build exclusions
│
├── 🧠 Environment
│   └── hospital_env/
│       ├── __init__.py
│       └── HospitalEnv.py      # Custom Gym environment
│
├── 🎓 Training
│   └── train/
│       ├── train.py            # Training script
│       └── config.yaml         # Configuration
│
├── 🔮 Inference
│   └── inference/
│       ├── predict.py          # Batch inference
│       └── api.py              # FastAPI server
│
├── 💾 Data
│   ├── models/                 # Saved models (git-ignored)
│   └── tb_logs/               # TensorBoard logs (git-ignored)
│
└── 📚 Documentation
    ├── README.md               # Full documentation
    ├── QUICK_START.md          # This file
    └── POWERSHELL_COMMANDS.md  # Command reference
```

---

## 🧪 Testing Your Setup

### **Test 1: Environment Check**
```powershell
docker run --rm custom-rl-env python -c "from hospital_env import HospitalInventoryEnvv; print('✓ Environment loaded')"
```

### **Test 2: Training Check**
```powershell
docker run --rm -e TIMESTEPS=100 -v ${PWD}/models:/app/models custom-rl-env python train/train.py
```

### **Test 3: API Check**
```powershell
# Start API
docker run -d --name test-api -p 8000:8000 -v ${PWD}/models:/app/models custom-rl-env uvicorn inference.api:app --host 0.0.0.0 --port 8000

# Wait a few seconds, then test
Start-Sleep -Seconds 5
curl http://localhost:8000/health

# Cleanup
docker stop test-api
docker rm test-api
```

---

## 🆘 Troubleshooting

### **Problem: "Model not found" error**
**Solution:** Train the model first
```powershell
docker run --rm -v ${PWD}/models:/app/models custom-rl-env python train/train.py
```

### **Problem: Port 8000 already in use**
**Solution:** Use a different port or stop existing process
```powershell
# Use different port
docker run -p 8001:8000 -v ${PWD}/models:/app/models custom-rl-env uvicorn inference.api:app --host 0.0.0.0 --port 8000

# Or find and kill process
netstat -ano | findstr :8000
```

### **Problem: Volume mounting not working**
**Solution:** Use absolute path
```powershell
docker run --rm -v "E:/Dev/docker/perishable-ml/models:/app/models" custom-rl-env
```

---

## 🎓 Learning Resources

1. **View API Documentation**: http://localhost:8000/docs (after starting API)
2. **Monitor Training**: http://localhost:6006 (TensorBoard)
3. **Read Full Docs**: See README.md
4. **Command Reference**: See POWERSHELL_COMMANDS.md

---

## ✅ Checklist for First Run

- [ ] Docker installed and running
- [ ] Project cloned/downloaded
- [ ] Navigate to project directory in PowerShell
- [ ] Build image: `docker build -t custom-rl-env .`
- [ ] Train model: `docker run --rm -v ${PWD}/models:/app/models custom-rl-env`
- [ ] Start API: `docker run -p 8000:8000 -v ${PWD}/models:/app/models custom-rl-env uvicorn inference.api:app --host 0.0.0.0 --port 8000`
- [ ] Test API: Visit http://localhost:8000/docs
- [ ] Start TensorBoard: `docker-compose up tensorboard`

---

## 🚀 Next Steps

1. **Experiment with hyperparameters** in `train/config.yaml`
2. **Customize the environment** in `hospital_env/HospitalEnv.py`
3. **Add new API endpoints** in `inference/api.py`
4. **Set up monitoring** with TensorBoard
5. **Deploy to production** using docker-compose

---

**🎉 You're ready to go! Start with the Quick Start commands above.**
