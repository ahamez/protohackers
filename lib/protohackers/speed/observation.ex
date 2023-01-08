defmodule Protohackers.Speed.Observation do
  alias Protohackers.Speed.Message.{Camera, Plate}

  defstruct mile: nil,
            timestamp: nil

  def new(%Plate{} = plate, %Camera{} = camera) do
    %__MODULE__{
      mile: camera.mile,
      timestamp: plate.timestamp
    }
  end
end
