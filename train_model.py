import os
from stable_baselines3 import DQN
from hospital_env.HospitalEnv import HospitalInventoryEnvv

def train(model_path: str = "models/dqn_inventory"):
    os.makedirs(os.path.dirname(model_path), exist_ok=True)
    env = HospitalInventoryEnvv()
    model = DQN(
        "MlpPolicy",
        env,
        verbose=1,
        learning_rate=1e-3,
        buffer_size=50000,
        batch_size=32,
        train_freq=4,
        target_update_interval=1000,
        exploration_fraction=0.3,
        exploration_final_eps=0.05,
        tensorboard_log="tb_logs",
    )
    model.learn(total_timesteps=20000)
    model.save(model_path)
    print(f"Model saved to {model_path}.zip")

if __name__ == "__main__":
    train()
