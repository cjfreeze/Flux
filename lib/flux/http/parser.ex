defmodule Flux.HTTP.Parser do
  require Logger
  import Flux.HTTP.Macros
  alias Flux.Conn

  @spec parse(Flux.HTTP.state(), String.t()) :: Flux.state()
  def parse(state, data) do
    parse_method(%{state | request: data}, data)
  end

  defp parse_method(%Conn{} = state, <<"GET ", rest::binary>>) do
    parse_uri(%{state | method: :GET}, rest)
  end

  defp parse_method(%Conn{} = state, <<"HEAD ", rest::binary>>) do
    parse_uri(%{state | method: :HEAD}, rest)
  end

  defp parse_method(%Conn{} = state, <<"POST ", rest::binary>>) do
    parse_uri(%{state | method: :POST}, rest)
  end

  defp parse_method(%Conn{} = state, <<"OPTIONS ", rest::binary>>) do
    parse_uri(%{state | method: :OPTIONS}, rest)
  end

  defp parse_method(%Conn{} = state, <<"PUT ", rest::binary>>) do
    parse_uri(%{state | method: :PUT}, rest)
  end

  defp parse_method(%Conn{} = state, <<"DELETE ", rest::binary>>) do
    parse_uri(%{state | method: :DELETE}, rest)
  end

  defp parse_method(%Conn{} = state, <<"TRACE ", rest::binary>>) do
    parse_uri(%{state | method: :TRACE}, rest)
  end

  defp parse_method(%Conn{} = state, <<"CONNECT ", rest::binary>>) do
    parse_uri(%{state | method: :CONNECT}, rest)
  end

  defp parse_method(_state, data) do
    # TODO Invesitgate error mesasge on unsupported method
    Logger.error("Unmatched method #{inspect(data)}")
  end

  defp parse_uri(state, data, acc \\ [])

  defp parse_uri(%Conn{} = state, <<" ", tail::binary>>, acc),
    do: parse_version(%{state | uri: Enum.reverse(acc)}, tail)

  defp parse_uri(%Conn{} = state, <<"?", tail::binary>>, acc),
    do: parse_query(%{state | uri: Enum.reverse(acc)}, tail)

  defp parse_uri(%Conn{} = state, <<head::binary-size(1), tail::binary>>, acc),
    do: parse_uri(state, tail, [head | acc])

  # POTENTIAL TODO for optimizations with older version of binary recursive pattern matching, ensure all binary match functions
  # have the match on every clause and in the first argument
  defp parse_uri(_state, <<>>, acc),
    do: Logger.error("Undexpectedly reached end of data with acc #{inspect(acc)}")

  defp parse_query(state, data, acc \\ [])

  defp parse_query(%Conn{} = state, <<" ", tail::binary>>, acc),
    do: parse_version(%{state | query: IO.iodata_to_binary(Enum.reverse(acc))}, tail)

  defp parse_query(%Conn{} = state, <<head::binary-size(1), tail::binary>>, acc),
    do: parse_query(state, tail, [head | acc])

  defp parse_query(_state, _data, acc),
    do: Logger.error("Undexpectedly reached end of data with acc #{inspect(acc)}")

  defp parse_version(%Conn{} = state, <<"HTTP/1.1", rest::binary>>) do
    advance_newline(%{state | version: :"HTTP/1.1"}, rest, &parse_headers/2)
  end

  defp parse_version(%Conn{} = state, <<"HTTP/1.0", rest::binary>>) do
    advance_newline(%{state | version: :"HTTP/1.0"}, rest, &parse_headers/2)
  end

  defp parse_version(_state, data) do
    Logger.error("Unmatched version #{inspect(data)}")
  end

  # probably stop using defmatch, do not use anon functions

  defmatch advance_newline(%Conn{} = state, <<:__MATCH__, rest::binary>>, next_step) do
    next_step.(state, rest)
  end

  defp advance_newline(state, data, next_step), do: next_step.(state, data)

  defmatch parse_headers(%Conn{} = state, <<:__MATCH__, rest::binary>>) do
    parse_body(state, rest)
  end

  defp parse_headers(state, data) do
    clear_newlines(state, data, &parse_header_key/2)
    # |> parse_header_key()
  end

  defp parse_header_key(state, data, acc \\ "")

  defp parse_header_key(%Conn{} = state, <<": ", rest::binary>>, acc) do
    parse_header_value(state, rest, acc)
  end

  defp parse_header_key(%Conn{} = state, <<head::binary-size(1), tail::binary>>, acc) do
    parse_header_key(state, tail, acc <> head)
  end

  defp parse_header_value(state, data, key, acc \\ "")

  defmatch parse_header_value(
             %{req_headers: headers} = state,
             <<:__MATCH__, rest::binary>>,
             key,
             val
           ) do
    downcased_key = String.downcase(key)
    downcased_val = String.downcase(val)
    # TODO Downcase the value based on the key
    # Potenitally do not downcase, but instead metaprogram all possible downcase possibilites
    new_state = Flux.HTTP.Headers.handle_header(state, downcased_key, downcased_val)
    # Move this into a callback variable passed in from Flux.HTTP that defaults to Headers

    parse_headers(%{new_state | req_headers: [{downcased_key, val} | headers]}, rest)
  end

  defp parse_header_value(%Conn{} = state, <<head::binary-size(1), tail::binary>>, key, acc),
    do: parse_header_value(state, tail, key, acc <> head)

  defmatch clear_newlines(%Conn{} = state, <<:__MATCH__, rest::binary>>, next_step) do
    clear_newlines(state, rest, next_step)
  end

  defp clear_newlines(state, data, next_step), do: next_step.(state, data)

  def parse_body(%Conn{} = state, body) do
    Map.put(state, :req_body, body)
  end
end
