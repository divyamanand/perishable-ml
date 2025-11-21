from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import numpy as np
from stable_baselines3 import DQN
from .hospital_env.HospitalEnv import HospitalInventoryEnvv  # Adjust import as needed

app = FastAPI()

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Allow all origins
    allow_credentials=True,
    allow_methods=["*"],  # Allow all HTTP methods
    allow_headers=["*"],  # Allow all headers
)

# Initialize environment and load model
env = HospitalInventoryEnvv()
model = DQN.load("dqn_inventory.zip")  # Ensure the model is correctly loaded

class Observation(BaseModel):
    inventory: list[float]
    pipeline: list[float]
    forecast: float

@app.post("/predict/")
def predict(obs: Observation):
    obs_array = np.array(obs.inventory + obs.pipeline + [obs.forecast], dtype=np.float32)
    action, _ = model.predict(obs_array, deterministic=True)
    return {"action": int(action)}
