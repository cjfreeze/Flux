defmodule Flux.Pool do
  alias Flux.Pool.Supervisor

  @moduledoc """
  transport: nil,
  pool_size: 10,
  port: 0,
  transport_opts: [],
  handler: nil,
  state: nil,
  """
  @type transport :: atom
  @type inet_port :: integer
  @type handler :: atom
  @type opts :: Keyword.t()
  @callback start_link(transport, inet_port, handler, opts) :: no_return()
  @callback child_spec(opts) :: Supervisor.child_spec()

  def start_link(transport, port, handler, handler_opts, opts) do
    transport
    |> format_supervisor_config(port, handler, handler_opts, opts)
    |> Supervisor.start_link()
  end

  def child_spec(opts) do
    transport = Keyword.fetch!(opts, :transport)
    port = Keyword.get(opts, :port, 4000)
    handler = Keyword.fetch!(opts, :handler)
    handler_opts = Keyword.get(opts, :handler_opts, [])

    transport
    |> format_supervisor_config(port, handler, handler_opts, opts)
    |> Supervisor.child_spec()
  end

  defp format_supervisor_config(transport, port, handler, handler_opts, opts) do
    pool_size = Keyword.get(opts, :pool_size, 10)
    transport_opts = Keyword.get(opts, :transport_opts, [])

    [
      transport: transport,
      port: port,
      handler: handler,
      handler_opts: handler_opts,
      pool_size: pool_size,
      transport_opts: transport_opts
    ]
  end

  def acknowlege do
    receive do
      {:pre_ack, transport, socket, timeout} ->
        transport.acknowlege(socket, timeout)
    end
  end
end
