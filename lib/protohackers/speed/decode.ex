defmodule Protohackers.Speed.Decode do
  def string(data) do
    case data do
      <<len::unsigned-big-8, str::binary-size(len), rest::binary>> ->
        {:ok, str, rest}

      _ ->
        :need_more_data
    end
  end

  def u32(data) do
    case data do
      <<value::unsigned-big-32, rest::binary>> ->
        {:ok, value, rest}

      _ ->
        :need_more_data
    end
  end

  def u16(data) do
    case data do
      <<value::unsigned-big-16, rest::binary>> ->
        {:ok, value, rest}

      _ ->
        :need_more_data
    end
  end

  def u16_array(data) do
    case data do
      <<nb_elems::unsigned-big-8, rest::binary>> ->
        parse_u16_array([], nb_elems, rest)

      _ ->
        :need_more_data
    end
  end

  # -- Private

  defp parse_u16_array(acc, 0, data) do
    {:ok, Enum.reverse(acc), data}
  end

  defp parse_u16_array(acc, nb_elems, data) do
    case data do
      <<value::unsigned-big-16, rest::binary>> ->
        parse_u16_array([value | acc], nb_elems - 1, rest)

      _ ->
        :need_more_data
    end
  end
end
