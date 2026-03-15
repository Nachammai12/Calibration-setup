defmodule CalibrationApp.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      CalibrationAppWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:calibration_app, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: CalibrationApp.PubSub},
      # Start a worker by calling: CalibrationApp.Worker.start_link(arg)
      # {CalibrationApp.Worker, arg},
      # Start to serve requests, typically the last entry
      CalibrationAppWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: CalibrationApp.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    CalibrationAppWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
