defmodule Flux.Supervisor do
  use Supervisor

  def init(_) do
    {:ok, %{}}
  end

  def start_link(opts) do
    pool = Keyword.get(opts, :pool, Flux.Pool)

    opts = Keyword.put_new(opts, :transport, Flux.Pool.Transport.TCP)

    children = [
      {pool, opts}
    ]

    opts = [strategy: :one_for_one, name: Flux.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
