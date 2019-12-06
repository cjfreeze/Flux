defmodule Flux.Pool.Transport do
  @type socket :: any
  @callback listen(integer, list) :: {:ok, socket} | {:error, any}
  @callback accept(socket, integer) :: {:ok, socket} | {:error, any}
  @callback acknowlege(socket, integer) :: :ok
  @callback send(socket, iodata) :: :ok | {:error, atom}
  @callback send_file(socket, binary) :: :ok | {:error, atom}
  @callback send_file(socket, binary, integer, integer | :all, list) :: :ok | {:error, atom}
  @callback read(socket, integer, integer) :: {:ok, iodata} | {:error, atom}
  @callback set_opts(socket, integer) :: {:ok, socket} | {:error, any}
  @callback controlling_process(socket, pid) :: :ok | {:error, atom}
  @callback messages :: {atom, atom, atom}
  @callback peer_name(socket) :: {:ok, {any, any}} | {:error, any}
end
