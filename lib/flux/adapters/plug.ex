defmodule Flux.Adapters.Plug do
  def upgrade(conn, endpoint) do
    %Plug.Conn{
      adapter: {__MODULE__, conn},
      host: conn.host,
      method: "#{conn.method}",
      owner: self(),
      path_info: split_path(conn.uri),
      peer: conn.peer,
      port: conn.port,
      remote_ip: conn.remote_ip,
      query_string: conn.query || "",
      req_headers: conn.req_headers,
      request_path: IO.iodata_to_binary(conn.uri),
      scheme: conn.opts.scheme
    }
    |> endpoint.call([])
  end

  defp split_path(path) when is_list(path) do
    path
    |> IO.iodata_to_binary()
    |> split_path()
  end

  defp split_path(path) do
    segments = :binary.split(path, "/", [:global])
    for segment <- segments, segment != "", do: segment
  end

  def send_resp(conn, status, headers, body) do
    updated_conn =
      conn
      |> Map.put(:resp_body, body)
      |> Map.put(:status, status)
      |> Map.put(:resp_headers, conn.resp_headers ++ headers)

    response = Flux.HTTP.Response.build(updated_conn)
    Flux.HTTP.Response.send_response(response, updated_conn)
  end

  def send_file(conn, status, headers, file, _, :all) do
    with {:ok, content} <- File.read(file) do
      do_send_file(conn, status, headers, content)
    end
  end

  def send_file(conn, status, headers, file, offset, len) do
    with {:ok, pid} <- File.open(file, [:binary]),
         {:ok, content} <- :file.pread(pid, offset, len) do
      do_send_file(conn, status, headers, content)
    end
  end

  defp do_send_file(conn, status, headers, body) do
    updated_conn =
      conn
      |> Map.put(:resp_body, body)
      |> Map.put(:status, status)
      |> Map.put(:resp_headers, conn.resp_headers ++ headers)

    response = Flux.HTTP.Response.build(updated_conn)
    Flux.HTTP.Response.send_response(response, updated_conn)
  end
end
