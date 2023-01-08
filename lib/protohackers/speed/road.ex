defmodule Protohackers.Speed.Road do
  alias Protohackers.Speed.Message.{Camera, Plate}
  alias Protohackers.Speed.Observation

  defstruct observations: [],
            limit: nil,
            id: nil

  def new(%Plate{} = plate, %Camera{} = camera) do
    %__MODULE__{
      observations: [Observation.new(plate, camera)],
      limit: camera.limit,
      id: camera.road
    }
  end
end
