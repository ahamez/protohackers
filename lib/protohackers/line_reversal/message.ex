defmodule Protohackers.LineReversal.Message do
  alias Protohackers.LineReversal.Message.{Ack, Close, Connect, Data}

  def decode(data) when is_binary(data) do
    case make_fields(data) do
      {:ok, ["ack" | fields]} -> Ack.decode(fields)
      {:ok, ["close" | fields]} -> Close.decode(fields)
      {:ok, ["connect" | fields]} -> Connect.decode(fields)
      {:ok, ["data" | fields]} -> Data.decode(fields)
      _ -> {:error, :unknown_message_type}
    end
  end

  # -- Private

  defp make_fields("/" <> data) do
    if String.ends_with?(data, "/") do
      {["" | fields], _} =
        data
        |> String.graphemes()
        |> Enum.reduce(
          {[""], :dont_escape},
          fn
            "/", {fields, :dont_escape} ->
              {["" | fields], :dont_escape}

            "\\", {fields, :dont_escape} ->
              {fields, :escape}

            c, {[field | fields], _} ->
              {[field <> c | fields], :dont_escape}
          end
        )

      {:ok, Enum.reverse(fields)}
    else
      {:error, :invalid_message}
    end
  end

  defp make_fields(_data) do
    {:error, :invalid_message}
  end
end
