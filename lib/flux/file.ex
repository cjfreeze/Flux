defmodule Flux.File do
  def read_file(file, offset \\ 0, length \\ :all)

  def read_file(file, _, :all) do
    with {:ok, content} <- File.read(file) do
      content
    else
      _ -> :error
    end
  end

  def read_file(file, offset, length) do
    with {:ok, pid} <- File.open(file, [:binary]),
         {:ok, content} <- :file.pread(pid, offset, length) do
      content
    else
      _ -> :error
    end
  end
end
