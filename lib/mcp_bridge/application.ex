defmodule McpBridge.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      McpBridgeWeb.Telemetry,
      McpBridge.Repo,
      {DNSCluster, query: Application.get_env(:mcp_bridge, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: McpBridge.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: McpBridge.Finch},
      {MLLP.Receiver, [port: 4090, dispatcher: MCPBridge.HL7.MLLPDispatcher]},
      MCPBridge.Scheduler,
      {Task.Supervisor, name: McpBridge.RPASupervisor},
      # Start a worker by calling: McpBridge.Worker.start_link(arg)
      # {McpBridge.Worker, arg},
      # Start to serve requests, typically the last entry
      McpBridgeWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: McpBridge.Supervisor]

    :ok =
      "python/pyproject.toml"
      |> File.read!()
      |> Pythonx.uv_init()

    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    McpBridgeWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
