from gymnasium.envs.registration import register

register(
    id='HospitalInventory-v1',
    entry_point='hospital_env.env:HospitalInventoryEnvv',
)
