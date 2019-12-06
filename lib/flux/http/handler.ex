defmodule Flux.HTTP.Handler do
  defmacro __using__(_) do
    quote do
      import Flux.Conn
      import Flux.HTTP
      @behaviour Flux.HTTP.Handler

      def handle_request(conn, _) do
        IO.inspect(conn)
      end

      defoverridable handle_request: 2
    end
  end

  @type conn :: Flux.Conn.t()
  @callback handle_request(conn, Keyword.t()) :: conn
end
