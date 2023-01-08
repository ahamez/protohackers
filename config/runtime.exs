import Config

if config_env() == :prod do
  config :logger,
    level: :info
end

config :protohackers,
  server: Mob,
  port: 10_000
