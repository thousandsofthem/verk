import Config

config :verk,
  queues: [queue_one: 5, queue_two: 5],
  redis_url: System.get_env("VERK_TEST_REDIS_URL", "redis://127.0.0.1:6379/15"),
  shutdown_timeout: 3_000
