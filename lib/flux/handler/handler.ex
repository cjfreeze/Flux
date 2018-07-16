defmodule Flux.Handler do
  def child_spec(opts) do
    %{
      id: Flux,
      start: {Flux.Supervisor, :start_link, [opts]},
      type: :supervisor,
      restart: :permanent
    }
  end

  def child_spec(scheme, endpoint, opts) do
    import Supervisor.Spec, warn: false
    worker(Flux.Supervisor, [[scheme: scheme, endpoint: endpoint] ++ opts])
  end

  def start_handling_process(socket, transport, state) do
    {:ok, spawn_link(__MODULE__, :handle_connection, [socket, transport, state])}
  end

  def handle_connection(socket, transport, state) do
    Nexus.acknowlege()
    Flux.HTTP.init(self(), nil, socket, transport, state)
  end
end
