defmodule Flux.Pool.Supervisor do
  use Supervisor
  require Logger
  alias Flux.Pool.Acceptor

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :supervisor,
      restart: :permanent,
      shutdown: 500
    }
  end

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(opts) do
    pool_opts = Keyword.get(opts, :pool_opts, [])
    transport = Keyword.fetch!(opts, :transport)
    handler = Keyword.get(pool_opts, :handler, Flux.HTTP)
    pool_size = Keyword.get(pool_opts, :pool_size, 100)
    transport_opts = Keyword.get(opts, :transport_opts, [])
    port = Keyword.get(opts, :port, 4000)
    {:ok, socket} = transport.listen(port, transport_opts)
    Logger.info("Now listening on port #{port}.")

    for id <- 0..pool_size do
      {Acceptor, [id: id, socket: socket, handler: handler, transport: transport, opts: opts]}
    end
    |> Supervisor.init(strategy: :one_for_one)
  end
end
