import numpy as np
import gymnasium as gym
from gymnasium import spaces
import pandas as pd
from prophet import Prophet
from gymnasium.envs.registration import register

class HospitalInventoryEnvv(gym.Env):


    metadata = {"render_modes": ["human", "terminal"], "render_fps": 1}
    def __init__(self, render_mode = None):
        super().__init__()
        # Parameters
        self.shelf_life = 7
        self.horizon = 365
        self.cost_holding = 0.5
        self.cost_waste = 2.0
        self.cost_shortage = 3.0

        # Internal state arrays
        self.pipeline = np.zeros(6, dtype=int)
        self.inventory = np.zeros(self.shelf_life, dtype=int)

        # Gymnasium spaces
        obs_high = np.concatenate([
            np.full(self.shelf_life, 1e6),  # inventory
            np.full(6, 1e6),                 # pipeline
            np.array([1e6])                  # forecast
        ]).astype(np.float32)
        self.observation_space = spaces.Box(
            low=0.0,
            high=obs_high,
            shape=(self.shelf_life + 6 + 1,),
            dtype=np.float32
        )
        self.action_space = spaces.Discrete(51)

        # Tracking variables
        self.current_day = 0
        self.demand_series = None
        self.history = []
        self.forecast = 0.0

    def _generate_demand(self):
        days = self.horizon + 30
        t = np.arange(days)
        base = 20
        amp = 10
        seasonal = base + amp * np.sin(2 * np.pi * t / 365)
        return np.random.poisson(seasonal)

    def _get_forecast(self):
        if len(self.history) < 10:
            return float(np.mean(self.history[-7:])) if len(self.history) >= 7 else float(np.mean(self.history))
        df = pd.DataFrame({
            'ds': pd.date_range(start='2023-01-01', periods=len(self.history), freq='D'),
            'y': self.history
        })
        m = Prophet(daily_seasonality=False, weekly_seasonality=False, yearly_seasonality=True)
        m.fit(df)
        future = m.make_future_dataframe(periods=3)
        forecast_df = m.predict(future)
        forecast_sum = forecast_df['yhat'][-3:].sum()  # Sum the last 3 forecasted values
        return float(forecast_sum)

    def _get_obs(self):
        return np.concatenate([self.inventory, self.pipeline, [self.forecast]]).astype(np.float32)

    def reset(self, seed=None, options=None):
        super().reset(seed=seed)
        # Reset state
        self.inventory[:] = 0
        self.pipeline[:] = 0
        self.current_day = 0
        # Initialize demands and history
        self.demand_series = self._generate_demand()
        self.history = list(self.demand_series[:self.current_day + 1])
        self.forecast = float(self._get_forecast())
        return self._get_obs(), {}

    def step(self, action):
        # Place order: arrives after 3 days
        action = max(0, self.forecast - self.inventory.sum())

        if action > 0 and self.pipeline[-1] == 0:
            self.pipeline[3] += int(action)

        # Advance pipeline
        arrivals = self.pipeline[0]
        self.pipeline = np.roll(self.pipeline, -1)
        self.pipeline[-1] = 0
        if arrivals > 0:
            self.inventory[0] += arrivals

        # Demand fulfillment
        demand = self.demand_series[self.current_day]
        remaining = demand
        for age in range(self.shelf_life - 1, -1, -1):
            if remaining <= 0:
                break
            used = min(self.inventory[age], remaining)
            self.inventory[age] -= used
            remaining -= used
        shortage = remaining

        # Rotate inventory ages and capture waste
        expired = self.inventory[-1]
        new_inv = np.zeros_like(self.inventory)
        new_inv[1:] = self.inventory[:-1]
        self.inventory = new_inv

        # Costs and reward
        holding = self.cost_holding * self.inventory.sum()
        waste = self.cost_waste * expired
        short_cost = self.cost_shortage * shortage
        total_cost = holding + waste + short_cost
        reward = -total_cost

        # Update day and history/forecast
        self.current_day += 1
        self.history.append(demand)
        self.forecast = float(self._get_forecast())

        # Termination flags
        terminated = self.current_day >= self.horizon
        truncated = False

        return self._get_obs(), reward, terminated, truncated, {"cost": total_cost, "shortage": shortage, "expired": expired}

    def render(self, mode='human'):
        print(f"Day {self.current_day}")
        print(f"Inventory ages: {self.inventory}")
        print(f"Pipeline: {self.pipeline}")
        print(f"Forecast for next day: {self.forecast:.2f}")




