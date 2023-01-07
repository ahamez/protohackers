import Config

if config_env() == :prod do
  config :logger,
    level: :info
end

config :protohackers,
  server: Database,
  port: 10_001
