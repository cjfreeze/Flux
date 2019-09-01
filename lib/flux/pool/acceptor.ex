defmodule Flux.Pool.Acceptor do
  alias Flux.Pool.Acceptor

  def child_spec(opts) do
    %{
      id: Keyword.fetch!(opts, :id),
      start: {Acceptor, :start_link, [Keyword.fetch!(opts, :socket), opts]},
      type: :worker,
      restart: :permanent,
      shutdown: 500
    }
  end

  def init(socket, opts) do
    %{
      socket: socket,
      transport: Keyword.fetch!(opts, :transport),
      handler: Keyword.fetch!(opts, :handler),
      opts: Keyword.fetch!(opts, :opts)
    }
  end

  def start_link(socket, opts) do
    {:ok, spawn_link(fn -> accept(init(socket, opts)) end)}
  end

  defp accept(%{transport: transport, socket: socket} = state) do
    socket
    |> transport.accept(:infinity)
    |> handle_accept(state)

    accept(state)
  end

  defp handle_accept({:ok, socket}, %{
         handler: handler,
         transport: transport,
         opts: opts
       }) do
    {:ok, pid} = handler.start_handling_process(Flux.Pool, socket, transport, opts)
    # TODO check error from here, could fail causing socket leak
    # case and work out what to do
    transport.controlling_process(socket, pid)
    send(pid, {:pre_ack, transport, socket, :infinity})
  end
end
