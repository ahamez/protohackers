defmodule Protohackers.Speed.Encode do
  def str(str) when is_binary(str) do
    len = byte_size(str)

    [<<len::unsigned-big-8>>, str]
  end

  def u16(value) when is_integer(value) do
    <<value::unsigned-big-16>>
  end

  def u32(value) when is_integer(value) do
    <<value::unsigned-big-32>>
  end
end
