import Config

if config_env() == :prod do
  config :logger,
    level: :info
end

server = Job

if server == LineReversal do
  config :logger, :console,
    format: "[$level][$metadata] $message\n",
    metadata: [:session, :acknowledged, :sent, :data_received_pos]
else
  config :logger, :console, format: "[$level] $message\n"
end

config :protohackers,
  server: server,
  port: 10_000
