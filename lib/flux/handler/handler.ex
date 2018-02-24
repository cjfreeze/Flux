defmodule Flux.Handler do
  def child_spec(opts) do
    %{
      id: Flux,
      start: {Flux, :start_link, opts},
      type: :worker,
      restart: :permanent,
      shutdown: 500
    }
  end

  def child_spec(scheme, endpoint, opts) do
    import Supervisor.Spec, warn: false
    worker(Flux, [scheme, endpoint, opts])
  end
end
