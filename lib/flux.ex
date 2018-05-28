defmodule Flux do
  @moduledoc """
  Documentation for Flux.
  """

  require Logger

  @doc """
  start_link/0

  ## Examples

      iex> Flux.start_link()

  """

  def start_link(scheme, endpoint, opts) do
    port = Keyword.get(opts, :port)
    otp_app = Keyword.get(opts, :otp_app)
    pool_size = 100
    state = %{
      scheme: scheme,
      endpoint: endpoint,
      otp_app: otp_app
    }

    Logger.info("Now listening on port #{port}.")
    do_start_link(scheme, port, pool_size, opts, state)
  end

  defp do_start_link(:http, port, pool_size, transport_opts, state) do
    Nexus.start_tcp(port, __MODULE__, [pool_size: pool_size, transport_opts: transport_opts], state)
  end

  defp do_start_link(:https, port, pool_size, transport_opts, state) do
    Nexus.start_ssl(port, __MODULE__, [pool_size: pool_size, transport_opts: transport_opts], state)
  end

  def start_handling_process(socket, transport, state) do
    {:ok, spawn_link(__MODULE__, :handle_connection, [socket, transport, state])}
  end

  def handle_connection(socket, transport, state) do
    Nexus.acknowlege()
    Flux.HTTP.init(self(), nil, socket, transport, state)
  end
end
