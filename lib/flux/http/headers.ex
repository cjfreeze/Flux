defmodule Flux.HTTP.Headers.Macros do
  defmacro def_fuzzy_handle_header(conn, key, value, do: do_block) do
    matches = [String.upcase(key), String.downcase(key), String.capitalize(key)]

    for key_match <- matches do
      quote do
        def handle_header(unquote(conn), unquote(key_match), unquote(value)),
          do: unquote(do_block)
      end
    end
  end
end

defmodule Flux.HTTP.Headers do
  import Flux.HTTP.Headers.Macros

  def_fuzzy_handle_header(conn, "transfer-coding", coding) do
    %{conn | transfer_coding: coding}
  end

  def_fuzzy_handle_header(conn, "content-length", length_string) do
    case Integer.parse(length_string) do
      {length, _} -> %{conn | content_length: length}
      _ -> conn
    end
  end

  def handle_header(conn, "upgrade", "websocket"), do: %{conn | upgrade: :websocket}

  def handle_header(%{keep_alive: true} = conn, "connection", "keep-alive"), do: conn

  def handle_header(%{resp_headers: resp_headers} = conn, "connection" = c, "keep-alive" = k) do
    %{conn | keep_alive: true, resp_headers: [{c, k} | resp_headers]}
  end

  def handle_header(%{accept: _} = conn, "accept", accepted_mimetypes) do
    %{conn | accept: parse_q(accepted_mimetypes)}
  end

  def handle_header(%{accept_charset: _} = conn, "accept-charset", accepted_charsets) do
    parsed_charsets_with_default =
      if Map.has_key?(parsed_charsets = parse_q(accepted_charsets), "ISO-8859-1") do
        parsed_charsets
      else
        Map.put(parsed_charsets, "ISO-8859-1", 1.0)
      end

    %{conn | accept_charset: parsed_charsets_with_default}
  end

  def handle_header(%{accept_encoding: _} = conn, "accept-language", accepted_languages) do
    %{conn | accept_language: parse_q(accepted_languages)}
  end

  def handle_header(%{accept_encoding: _} = conn, "accept-encoding", accepted_codings) do
    %{conn | accept_encoding: parse_q(accepted_codings)}
  end

  def handle_header(%{host: _} = conn, "host", host) do
    %{conn | host: host}
  end

  def handle_header(conn, _, _), do: conn

  def parse_q(""), do: %{}
  def parse_q(q_list), do: do_parse_q(q_list)

  defp do_parse_q(q_list, item_buffer \\ "", map_result \\ %{})

  defp do_parse_q(<<", ", tail::binary>>, item_buffer, map_result) do
    map = Map.put(map_result, item_buffer, 1.0)
    do_parse_q(tail, "", map)
  end

  defp do_parse_q(<<",", tail::binary>>, item_buffer, map_result) do
    map = Map.put(map_result, item_buffer, 1.0)
    do_parse_q(tail, "", map)
  end

  defp do_parse_q(<<";q=", tail::binary>>, item_buffer, map_result) do
    do_parse_q_value(tail, item_buffer, "", map_result)
  end

  defp do_parse_q(<<"; q=", tail::binary>>, item_buffer, map_result) do
    do_parse_q_value(tail, item_buffer, "", map_result)
  end

  defp do_parse_q(<<" ", tail::binary>>, item_buffer, map_result) do
    do_parse_q(tail, item_buffer, map_result)
  end

  defp do_parse_q(<<head::binary-size(1), tail::binary>>, item_buffer, map_result) do
    do_parse_q(tail, item_buffer <> head, map_result)
  end

  defp do_parse_q("", item_buffer, map_result) do
    Map.put(map_result, item_buffer, 1.0)
  end

  defp do_parse_q_value(q_list, item, q_buffer, map_result)

  defp do_parse_q_value(<<", ", tail::binary>>, item, q_buffer, map_result) do
    map = Map.put(map_result, item, to_float(q_buffer))
    do_parse_q(tail, "", map)
  end

  defp do_parse_q_value(<<",", tail::binary>>, item, q_buffer, map_result) do
    map = Map.put(map_result, item, to_float(q_buffer))
    do_parse_q(tail, "", map)
  end

  defp do_parse_q_value(<<" ", tail::binary>>, item, q_buffer, map_result) do
    do_parse_q_value(tail, item, q_buffer, map_result)
  end

  defp do_parse_q_value(<<head::binary-size(1), tail::binary>>, item, q_buffer, map_result) do
    do_parse_q_value(tail, item, q_buffer <> head, map_result)
  end

  defp do_parse_q_value("", item, q_buffer, map_result) do
    Map.put(map_result, item, to_float(q_buffer))
  end

  defp to_float("1"), do: 1.0
  defp to_float("0"), do: 0.0
  defp to_float(q), do: String.to_float(q)
end
