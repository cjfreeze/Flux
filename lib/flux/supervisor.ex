defmodule Flux.Supervisor do
  use Supervisor

  def init(_) do
    {:ok, %{}}
  end

  def start_link(opts) do
    otp_app = Keyword.get(opts, :otp_app)
    handler = Keyword.get(opts, :handler)
    scheme = Keyword.fetch!(opts, :scheme)
    endpoint = Keyword.fetch!(opts, :endpoint)

    state = %{
      scheme: scheme,
      endpoint: endpoint,
      otp_app: otp_app,
      handler: handler
    }

    nexus_opts = [
      transport: scheme_to_transport(scheme),
      pool_size: 100,
      state: state,
      handler: Flux.Handler,
      transport_opts: opts,
      otp_app: otp_app
    ]

    children = [
      {Nexus, nexus_opts}
    ]

    opts = [strategy: :one_for_one, name: Flux.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp scheme_to_transport(:http), do: :tcp
  defp scheme_to_transport(:https), do: :ssl

  # defp do_start_link(:http, port, pool_size, transport_opts, state) do
  #   Nexus.start_tcp(port, __MODULE__, [pool_size: pool_size, transport_opts: transport_opts], state)
  # end

  # defp do_start_link(:https, port, pool_size, transport_opts, state) do
  #   Nexus.start_ssl(port, __MODULE__, [pool_size: pool_size, transport_opts: transport_opts], state)
  # end
end
