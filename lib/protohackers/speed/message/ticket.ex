defmodule Protohackers.Speed.Message.Ticket do
  alias Protohackers.Speed.{Observation, Road, Vehicle}

  defstruct [:plate, :road, :mile1, :timestamp1, :mile2, :timestamp2, :speed]

  def new(
        %Observation{} = observation_from,
        %Observation{} = observation_to,
        %Road{} = road,
        %Vehicle{} = vehicle,
        speed
      ) do
    %__MODULE__{
      plate: vehicle.plate,
      road: road.id,
      mile1: observation_from.mile,
      timestamp1: observation_from.timestamp,
      mile2: observation_to.mile,
      timestamp2: observation_to.timestamp,
      speed: speed
    }
  end
end

defimpl Protohackers.Speed.Message.Encode, for: Protohackers.Speed.Message.Ticket do
  alias Protohackers.Speed.Encode

  def encode(ticket) do
    [
      <<0x21>>,
      Encode.str(ticket.plate),
      Encode.u16(ticket.road),
      Encode.u16(ticket.mile1),
      Encode.u32(ticket.timestamp1),
      Encode.u16(ticket.mile2),
      Encode.u32(ticket.timestamp2),
      Encode.u16(trunc(ticket.speed * 100))
    ]
  end
end
