defmodule Flux.Test.Endpoint do
  def call(%{request_path: "/file"} = conn, _) do
    {adapter, flux_conn} = conn.adapter
    adapter.send_file(flux_conn, 200, [], "#{System.tmp_dir()}/file.txt", 0, :all)
  end

  def call(%{request_path: "/file_offset"} = conn, _) do
    {adapter, flux_conn} = conn.adapter
    adapter.send_file(flux_conn, 200, [], "#{System.tmp_dir()}/file.txt", 6, 5)
  end

  def call(conn, _) do
    {adapter, flux_conn} = conn.adapter
    adapter.send_resp(flux_conn, 200, [], "Test")
  end
end
