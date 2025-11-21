"""
Training script for Hospital Inventory RL Environment
Supports environment variables for hyperparameter configuration
"""
import os
from stable_baselines3 import DQN
from hospital_env.HospitalEnv import HospitalInventoryEnvv


def train(
    model_path: str = "models/dqn_inventory",
    timesteps: int = None,
    learning_rate: float = None,
    buffer_size: int = None,
    batch_size: int = None,
):
    """
    Train the DQN model on Hospital Inventory Environment
    
    Args:
        model_path: Path to save the trained model
        timesteps: Total training timesteps (default: 20000)
        learning_rate: Learning rate (default: 1e-3)
        buffer_size: Replay buffer size (default: 50000)
        batch_size: Batch size for training (default: 32)
    """
    # Read from environment variables if available (for Docker/CI-CD)
    timesteps = timesteps or int(os.getenv("TIMESTEPS", "20000"))
    learning_rate = learning_rate or float(os.getenv("LEARNING_RATE", "1e-3"))
    buffer_size = buffer_size or int(os.getenv("BUFFER_SIZE", "50000"))
    batch_size = batch_size or int(os.getenv("BATCH_SIZE", "32"))
    
    # Ensure model directory exists
    os.makedirs(os.path.dirname(model_path), exist_ok=True)
    
    # Create environment
    env = HospitalInventoryEnvv()
    
    print(f"Starting training with:")
    print(f"  Timesteps: {timesteps}")
    print(f"  Learning Rate: {learning_rate}")
    print(f"  Buffer Size: {buffer_size}")
    print(f"  Batch Size: {batch_size}")
    
    # Initialize model
    model = DQN(
        "MlpPolicy",
        env,
        verbose=1,
        learning_rate=learning_rate,
        buffer_size=buffer_size,
        batch_size=batch_size,
        train_freq=4,
        target_update_interval=1000,
        exploration_fraction=0.3,
        exploration_final_eps=0.05,
        tensorboard_log="tb_logs",
    )
    
    # Train
    model.learn(total_timesteps=timesteps)
    
    # Save model
    model.save(model_path)
    print(f"✓ Model saved to {model_path}.zip")
    print(f"✓ Training completed successfully!")


if __name__ == "__main__":
    train()
