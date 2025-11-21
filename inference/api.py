"""
FastAPI server for Hospital Inventory RL model inference
Provides REST API endpoints for model predictions
"""
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field
from typing import Dict, Any
import numpy as np
from stable_baselines3 import DQN
from hospital_env.HospitalEnv import HospitalInventoryEnvv


# Initialize FastAPI app
app = FastAPI(
    title="Hospital Inventory RL API",
    description="REST API for Hospital Inventory Management using Reinforcement Learning",
    version="1.0.0"
)

# Global model variable (loaded on startup)
model = None
env = None


class ObservationInput(BaseModel):
    """Input schema for prediction endpoint"""
    inventory: list[float] = Field(..., description="Inventory levels by age (7 values)", min_length=7, max_length=7)
    pipeline: list[float] = Field(..., description="Order pipeline (6 values)", min_length=6, max_length=6)
    forecast: float = Field(..., description="Demand forecast value")
    
    class Config:
        json_schema_extra = {
            "example": {
                "inventory": [10.0, 8.0, 6.0, 4.0, 2.0, 1.0, 0.0],
                "pipeline": [5.0, 0.0, 10.0, 0.0, 0.0, 0.0],
                "forecast": 15.5
            }
        }


class PredictionOutput(BaseModel):
    """Output schema for prediction endpoint"""
    action: int = Field(..., description="Predicted order quantity (0-50)")
    observation: Dict[str, Any] = Field(..., description="Input observation used for prediction")


@app.on_event("startup")
async def load_model():
    """Load model on server startup"""
    global model, env
    try:
        model = DQN.load("models/dqn_inventory")
        env = HospitalInventoryEnvv()
        print("✓ Model loaded successfully from models/dqn_inventory.zip")
    except Exception as e:
        print(f"✗ Error loading model: {e}")
        raise


@app.get("/")
async def root():
    """Health check endpoint"""
    return {
        "status": "running",
        "message": "Hospital Inventory RL API is operational",
        "endpoints": {
            "predict": "/predict",
            "health": "/health",
            "docs": "/docs"
        }
    }


@app.get("/health")
async def health_check():
    """Detailed health check"""
    return {
        "status": "healthy" if model is not None else "unhealthy",
        "model_loaded": model is not None,
        "environment": "HospitalInventoryEnvv"
    }


@app.post("/predict", response_model=PredictionOutput)
async def predict(observation: ObservationInput):
    """
    Predict optimal order quantity given current state
    
    Args:
        observation: Current state (inventory, pipeline, forecast)
    
    Returns:
        Predicted action (order quantity 0-50)
    """
    if model is None:
        raise HTTPException(status_code=503, detail="Model not loaded")
    
    try:
        # Construct observation array
        obs_array = np.array(
            observation.inventory + observation.pipeline + [observation.forecast],
            dtype=np.float32
        )
        
        # Predict action
        action, _ = model.predict(obs_array, deterministic=True)
        action_int = int(action)
        
        return PredictionOutput(
            action=action_int,
            observation={
                "inventory": observation.inventory,
                "pipeline": observation.pipeline,
                "forecast": observation.forecast
            }
        )
    
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Prediction error: {str(e)}")


@app.post("/batch_predict")
async def batch_predict(observations: list[ObservationInput]):
    """
    Batch prediction for multiple observations
    
    Args:
        observations: List of observations
    
    Returns:
        List of predictions
    """
    if model is None:
        raise HTTPException(status_code=503, detail="Model not loaded")
    
    try:
        results = []
        for obs in observations:
            obs_array = np.array(
                obs.inventory + obs.pipeline + [obs.forecast],
                dtype=np.float32
            )
            action, _ = model.predict(obs_array, deterministic=True)
            results.append({"action": int(action)})
        
        return {"predictions": results, "count": len(results)}
    
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Batch prediction error: {str(e)}")


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
