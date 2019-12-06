defmodule Flux.Support.Conn do
  alias Flux.Pool.Transport.TCP
  alias Flux.Support.Transport
  alias Flux.Conn

  @tcp_client_opts [
    :binary,
    active: false,
    packet: :raw,
    reuseaddr: true,
    keepalive: true,
    exit_on_close: false
  ]

  def mocked_transport_conn(attrs \\ []) do
    with {:ok, listen_socket} <- Transport.listen(4000, []),
         {:ok, socket} <- Transport.accept(listen_socket, 1000) do
      %Conn{transport: Transport, socket: socket}
      |> Map.merge(Enum.into(attrs, %{}))
    end
  end

  def tcp_transport_conn(attrs \\ []) do
    with listen_socket = get_listening_socket(),
         pid = self(),
         task =
           Task.async(fn ->
             {:ok, socket} = :gen_tcp.connect({127, 0, 0, 1}, 5679, @tcp_client_opts, 1000)
             :gen_tcp.controlling_process(socket, pid)
             {:ok, socket}
           end),
         {:ok, socket} <- TCP.accept(listen_socket, 1000),
         {:ok, client_socket} = Task.await(task) do
      %Conn{transport: TCP, socket: socket, private: %{client_socket: client_socket}}
      |> Map.merge(Enum.into(attrs, %{}))
    end
  end

  defp get_listening_socket do
    if Process.whereis(:test_socket_agent) do
      Agent.get(:test_socket_agent, fn f -> f end)
    else
      {:ok, listen_socket} = TCP.listen(5679, [])
      Agent.start_link(fn -> listen_socket end, name: :test_socket_agent)
      listen_socket
    end
  end

  def set_test_buffer(conn, buffer) do
    case conn.transport do
      Transport -> Transport.put_fake_test_buffer(conn.socket, buffer)
      TCP -> :gen_tcp.send(conn.private.client_socket, buffer)
    end
  end
end
