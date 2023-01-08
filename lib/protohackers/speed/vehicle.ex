defmodule Protohackers.Speed.Vehicle do
  alias Protohackers.Speed.Message.{Camera, Plate}
  alias Protohackers.Speed.Road

  defstruct roads: %{},
            days_with_ticket: MapSet.new(),
            plate: nil

  def new(%Plate{} = plate, %Camera{} = camera) do
    %__MODULE__{
      roads: %{
        camera.road => Road.new(plate, camera)
      },
      plate: plate.plate
    }
  end
end
