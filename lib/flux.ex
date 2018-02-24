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
    ranch_name = :ranch
    pool_count = 100
    ranch_opts = [port: port]

    opts = %{
      scheme: scheme,
      endpoint: endpoint,
      otp_app: otp_app
    }

    Logger.info("Now listening on port #{port}.")
    :ranch.start_listener(ranch_name, pool_count, :ranch_tcp, ranch_opts, __MODULE__, opts)
  end

  def start_link(ref, socket, transport, opts) do
    {:ok, spawn_link(__MODULE__, :handle_connection, [ref, socket, transport, opts])}
  end

  def handle_connection(ref, socket, transport, opts) do
    :ok = :ranch.accept_ack(ref)
    Flux.HTTP.init(self(), ref, socket, transport, opts)
  end
end
