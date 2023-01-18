defmodule Protohackers.Insecure.CipherOperations do
  defguard is_positive(value) when is_integer(value) and value >= 0
  defguard is_byte(value) when is_positive(value) and value < 256

  @chars Protohackers.Insecure.Chars.get()
  @noop Nx.iota({256, 256}, names: [:byte, :pos], axis: :byte, type: :u8)
  @pos @noop |> Nx.transpose() |> Nx.reshape({256, 256}, names: [:byte, :pos])

  def noop(), do: @noop

  def reversebits(%Nx.Tensor{} = tensor) do
    Nx.map(tensor, fn byte ->
      byte |> Nx.to_number() |> reversebits()
    end)
  end

  def reversebits(byte) when is_byte(byte) do
    <<b0::1, b1::1, b2::1, b3::1, b4::1, b5::1, b6::1, b7::1>> = <<byte>>
    <<res>> = <<b7::1, b6::1, b5::1, b4::1, b3::1, b2::1, b1::1, b0::1>>

    res
  end

  def xor(%Nx.Tensor{} = tensor, value) when is_byte(value) do
    Nx.bitwise_xor(tensor, value)
  end

  def xor(byte, value) when is_byte(byte) and is_positive(value) do
    Bitwise.bxor(byte, Integer.mod(value, 256))
  end

  def xor_pos(%Nx.Tensor{} = tensor) do
    Nx.bitwise_xor(tensor, @pos)
  end

  def add(%Nx.Tensor{} = tensor, value) when is_byte(value) do
    Nx.add(tensor, value)
  end

  def add(byte, value) when is_byte(byte) and is_positive(value) do
    Integer.mod(byte + value, 256)
  end

  def add_pos(%Nx.Tensor{} = tensor) do
    Nx.add(tensor, @pos)
  end

  def invert(%Nx.Tensor{} = tensor) do
    {indices, updates} =
      for pos <- 0..255, byte <- @chars, reduce: {[], []} do
        {indices, updates} ->
          x = tensor[byte: byte, pos: pos] |> Nx.to_number()
          {[[x, pos] | indices], [byte | updates]}
      end

    Nx.indexed_put(tensor, Nx.tensor(indices), Nx.tensor(updates, type: :u8))
  end

  def sub(byte, value) when is_byte(byte) and is_positive(value) do
    Integer.mod(byte - value, 256)
  end
end
