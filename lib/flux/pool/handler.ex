defmodule Flux.Pool.Handler do
  @type socket :: any
  @type pool :: atom
  @type transport :: atom
  @type opts :: Keyword.t()
  @callback start_handling_process(pool, socket, transport, opts) :: {:ok, pid}
end
