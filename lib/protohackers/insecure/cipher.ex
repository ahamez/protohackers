defmodule Protohackers.Insecure.Cipher do
  alias Protohackers.Insecure.CipherOperations

  defguard is_positive(value) when is_integer(value) and value >= 0
  defguard is_byte(value) when is_positive(value) and value < 256

  defstruct [:encoder, :decoder, :operations, :type]

  def new(cipher_spec, opts \\ [])

  def new(cipher_spec, opts) when is_binary(cipher_spec) do
    with {:ok, operations, rest} <- parse(cipher_spec, []),
         {:ok, cipher} <- new(operations, opts) do
      {:ok, cipher, rest}
    end
  end

  def new(operations, opts) when is_list(operations) do
    case Keyword.get(opts, :type, :nx) do
      :nx -> new_nx(operations)
      :byte_wise -> new_byte_wise(operations)
      _ -> {:error, :invalid_cipher_type}
    end
  end

  def encode(%__MODULE__{type: :nx} = cipher, byte, pos)
      when is_byte(byte) and is_positive(pos) do
    Nx.to_number(cipher.encoder[byte: byte, pos: Integer.mod(pos, 256)])
  end

  def encode(%__MODULE__{type: :byte_wise} = cipher, byte, pos) do
    Enum.reduce(
      cipher.operations,
      byte,
      fn
        {:reversebits, []}, byte -> CipherOperations.reversebits(byte)
        {:xor, [operand]}, byte -> CipherOperations.xor(byte, operand)
        {:xor_pos, []}, byte -> CipherOperations.xor(byte, Integer.mod(pos, 256))
        {:add, [operand]}, byte -> CipherOperations.add(byte, operand)
        {:add_pos, []}, byte -> CipherOperations.add(byte, Integer.mod(pos, 256))
      end
    )
  end

  def decode(%__MODULE__{type: :nx} = cipher, byte, pos)
      when is_byte(byte) and is_positive(pos) do
    Nx.to_number(cipher.decoder[byte: byte, pos: Integer.mod(pos, 256)])
  end

  def decode(%__MODULE__{type: :byte_wise} = cipher, byte, pos) do
    Enum.reduce(
      Enum.reverse(cipher.operations),
      byte,
      fn
        {:reversebits, []}, byte -> CipherOperations.reversebits(byte)
        {:xor, [operand]}, byte -> CipherOperations.xor(byte, operand)
        {:xor_pos, []}, byte -> CipherOperations.xor(byte, Integer.mod(pos, 256))
        {:add, [operand]}, byte -> CipherOperations.sub(byte, operand)
        {:add_pos, []}, byte -> CipherOperations.sub(byte, Integer.mod(pos, 256))
      end
    )
  end

  # -- Private

  defp new_nx(operations) do
    with {:ok, encoder} <- make_nx_encoder(operations),
         {:ok, decoder} <- make_nx_decoder(encoder) do
      {
        :ok,
        %__MODULE__{
          encoder: encoder,
          decoder: decoder,
          operations: operations,
          type: :nx
        }
      }
    end
  end

  defp new_byte_wise(operations) do
    cipher = %__MODULE__{
      operations: operations,
      type: :byte_wise
    }

    if noop_byte_wise?(cipher) do
      {:error, :noop_cipher}
    else
      {:ok, cipher}
    end
  end

  defp make_nx_encoder(operations) do
    encoder =
      Enum.reduce(
        operations,
        CipherOperations.noop(),
        fn {fun, args}, tensor ->
          apply(CipherOperations, fun, [tensor | args])
        end
      )

    if encoder != CipherOperations.noop() do
      {:ok, encoder}
    else
      {:error, :noop_cipher}
    end
  end

  defp make_nx_decoder(encoder) do
    {:ok, CipherOperations.invert(encoder)}
  end

  defp noop_byte_wise?(%__MODULE__{type: :byte_wise} = cipher) do
    Enum.reduce_while(0..255, true, fn pos, is_noop ->
      res =
        Enum.reduce_while(0..255, is_noop, fn byte, is_noop ->
          if encode(cipher, byte, pos) != byte do
            {:halt, false}
          else
            {:cont, is_noop}
          end
        end)

      if res do
        {:cont, true}
      else
        {:halt, false}
      end
    end)
  end

  defp parse(<<>>, _acc), do: {:error, :need_more_data}

  defp parse(<<0, rest::binary>>, acc), do: {:ok, Enum.reverse(acc), rest}

  defp parse(<<1, rest::binary>>, acc) do
    parse(rest, [{:reversebits, []} | acc])
  end

  defp parse(<<2, operand, rest::binary>>, acc) do
    parse(rest, [{:xor, [operand]} | acc])
  end

  defp parse(<<3, rest::binary>>, acc) do
    parse(rest, [{:xor_pos, []} | acc])
  end

  defp parse(<<4, operand, rest::binary>>, acc) do
    parse(rest, [{:add, [operand]} | acc])
  end

  defp parse(<<5, rest::binary>>, acc) do
    parse(rest, [{:add_pos, []} | acc])
  end

  defp parse(_data, _acc) do
    {:error, :invalid_cipher_spec}
  end
end
