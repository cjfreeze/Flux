defmodule Flux.Support.Transport do
  @behaviour Flux.Pool.Transport
  def listen(_, _), do: {:ok, :fake_socket}
  def accept(:fake_socket, _), do: Agent.start_link(fn -> "" end)
  def acknowlege(_, _), do: :ok
  def send(_, "socket ded"), do: {:error, :econnrefused}
  def send(_, _), do: :ok
  def send_file(_, "socket ded"), do: {:error, :econnrefused}
  def send_file(_, _), do: :ok
  def send_file(_, _, _, _, _), do: :ok

  def read(agent, length, _) do
    Agent.get_and_update(
      agent,
      fn buffer -> String.split_at(buffer, length) end
    )
  end

  def set_opts(socket, _), do: {:ok, socket}

  def controlling_process(_, _), do: :ok

  def messages, do: {:this, :doesnt, :matter}
  def peer_name(_), do: {:ok, {:fake, :peername}}

  def put_fake_test_buffer(agent, buffer) do
    Agent.update(agent, fn _ -> buffer end)
  end
end
