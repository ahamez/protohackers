defmodule Protohackers.Util do
  def peername(socket) do
    {:ok, {address, port}} = :inet.peername(socket)

    "#{:inet.ntoa(address)}:#{port}"
  end
end
