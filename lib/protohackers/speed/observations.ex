defmodule Protohackers.Speed.Observations do
  # require Logger

  alias Protohackers.Speed.{Observation, Road, Vehicle}
  alias Protohackers.Speed.Message.Ticket

  def insert_observation_into_vehicle(nil = _vehicle, plate, camera) do
    Vehicle.new(plate, camera)
  end

  def insert_observation_into_vehicle(vehicle, plate, camera) do
    %Road{} = road = insert_observation_into_road(vehicle.roads[camera.road], plate, camera)

    %Vehicle{vehicle | roads: Map.put(vehicle.roads, camera.road, road)}
  end

  def insert_observation_into_road(nil = _road, plate, camera) do
    Road.new(plate, camera)
  end

  def insert_observation_into_road(road, plate, camera) do
    observations = insert_observation([], road.observations, plate, camera)

    %Road{road | observations: observations}
  end

  def insert_observation(acc, [], plate, camera) do
    Enum.reverse([Observation.new(plate, camera) | acc])
  end

  def insert_observation(acc, [o | os] = observations, plate, camera) do
    if plate.timestamp < o.timestamp do
      new_observation = Observation.new(plate, camera)

      Enum.reverse(acc) ++ [new_observation | observations]
    else
      insert_observation([o | acc], os, plate, camera)
    end
  end

  def tickets([] = _observations, _road, _vehicle) do
    []
  end

  def tickets([_] = _observations, _road, _vehicle) do
    []
  end

  def tickets([observation_from | observations], road, vehicle) do
    {_last_observation, tickets} =
      Enum.reduce(
        observations,
        {observation_from, []},
        fn observation_to, {observation_from, tickets} ->
          speed = compute_speed(observation_from, observation_to)
          # Logger.debug("Computed speed for vehicle #{vehicle.plate}: #{speed}")

          if speed > road.limit do
            ticket = Ticket.new(observation_from, observation_to, road, vehicle, speed)
            {observation_to, [ticket | tickets]}
          else
            {observation_to, tickets}
          end
        end
      )

    tickets
  end

  def get_days_of_ticket(%Ticket{} = ticket) do
    {
      Float.floor(ticket.timestamp1 / 86_400) |> trunc(),
      Float.floor(ticket.timestamp2 / 86_400) |> trunc()
    }
  end

  # -- Private

  defp compute_speed(observation_from, observation_to) do
    speed =
      (observation_to.mile - observation_from.mile) /
        (observation_to.timestamp - observation_from.timestamp) * 3_600

    abs(speed)
  end
end
