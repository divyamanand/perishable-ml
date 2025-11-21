"""
Inference script for Hospital Inventory RL Environment
Runs a trained model through a full episode and displays results
"""
import numpy as np
from stable_baselines3 import DQN
from hospital_env.HospitalEnv import HospitalInventoryEnvv


def run_inference(model_path: str = "models/dqn_inventory", num_episodes: int = 1):
    """
    Run inference with a trained model
    
    Args:
        model_path: Path to the saved model
        num_episodes: Number of episodes to run
    """
    # Load environment and model
    env = HospitalInventoryEnvv(render_mode=None)
    model = DQN.load(model_path)
    
    print(f"✓ Model loaded from {model_path}.zip")
    print(f"Running {num_episodes} episode(s)...\n")
    
    for episode in range(num_episodes):
        obs, _ = env.reset()
        done = False
        total_reward = 0
        step_count = 0
        total_cost = 0
        total_shortage = 0
        total_expired = 0
        
        print(f"{'='*60}")
        print(f"Episode {episode + 1}")
        print(f"{'='*60}")
        
        while not done:
            # Predict action
            action, _ = model.predict(obs, deterministic=True)
            
            # Take step
            obs, reward, terminated, truncated, info = env.step(action)
            done = terminated or truncated
            
            # Track metrics
            total_reward += reward
            step_count += 1
            total_cost += info.get("cost", 0)
            total_shortage += info.get("shortage", 0)
            total_expired += info.get("expired", 0)
            
            # Print step info every 30 days
            if step_count % 30 == 0:
                print(f"Day {step_count:3d} | Action: {action:2d} | "
                      f"Reward: {reward:7.2f} | Cost: {info['cost']:7.2f} | "
                      f"Shortage: {info['shortage']:2d} | Expired: {info['expired']:2d}")
        
        # Episode summary
        print(f"\n{'─'*60}")
        print(f"Episode Summary:")
        print(f"  Total Steps:    {step_count}")
        print(f"  Total Reward:   {total_reward:.2f}")
        print(f"  Total Cost:     {total_cost:.2f}")
        print(f"  Avg Cost/Day:   {total_cost/step_count:.2f}")
        print(f"  Total Shortage: {total_shortage}")
        print(f"  Total Expired:  {total_expired}")
        print(f"{'─'*60}\n")
    
    env.close()
    print("✓ Inference completed successfully!")


if __name__ == "__main__":
    run_inference()
