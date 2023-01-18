defmodule Protohackers.Insecure.Chars do
  def get() do
    [
      ['\n', '-', '*', ' ', ','],
      Enum.to_list(?a..?z),
      Enum.to_list(?A..?Z),
      Enum.to_list(?0..?9)
    ]
    |> Enum.join()
    |> String.to_charlist()
    |> Enum.sort()
  end
end
