defmodule McpBridge.Repo do
  use Ecto.Repo,
    otp_app: :mcp_bridge,
    adapter: Ecto.Adapters.Postgres
end
