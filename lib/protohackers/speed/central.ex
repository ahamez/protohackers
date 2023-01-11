defmodule Protohackers.Speed.Central do
  use GenServer

  require Logger

  alias Protohackers.Speed.Message.{Camera, Plate}
  alias Protohackers.Speed.{Observations, Vehicle}

  defmodule State do
    defstruct vehicles: %{},
              tickets_to_send: []
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, [], opts)
  end

  @impl true
  def init([]) do
    schedule_tickets_send()

    {:ok, %State{}}
  end

  # -- API

  def add_observation(pid, %Plate{} = plate, %Camera{} = camera) do
    GenServer.call(pid, {:add_observation, plate, camera})
  end

  # -- Callbacks

  @impl true
  def handle_call({:add_observation, plate, camera}, _from, state) do
    # Logger.debug("Add observation #{inspect(plate)} from #{inspect(camera)}")

    vehicle =
      Observations.insert_observation_into_vehicle(state.vehicles[plate.plate], plate, camera)

    # Logger.debug("Vehicle: #{inspect(vehicle)}")

    tickets =
      Observations.tickets(
        vehicle.roads[camera.road].observations,
        vehicle.roads[camera.road],
        vehicle
      )

    Logger.debug("Tickets for vehicle #{vehicle.plate}: #{inspect(tickets)}")

    tickets_to_send = state.tickets_to_send ++ tickets
    vehicles = Map.put(state.vehicles, plate.plate, vehicle)

    {
      :reply,
      :ok,
      %State{state | vehicles: vehicles, tickets_to_send: tickets_to_send}
    }
  end

  @impl true
  def handle_info(:send_tickets, state) do
    {tickets_to_send, vehicles} =
      Enum.reduce(
        state.tickets_to_send,
        {[], state.vehicles},
        fn ticket, {tickets_to_send, vehicles} ->
          vehicle = vehicles[ticket.plate]
          {day1, day2} = Observations.get_days_of_ticket(ticket)

          if not MapSet.member?(vehicle.days_with_ticket, day1) and
               not MapSet.member?(vehicle.days_with_ticket, day2) do
            Logger.debug(
              "New ticket for day #{inspect({day1, day2})} for vehicle #{ticket.plate}"
            )

            case Registry.lookup(DispatcherRegistry, ticket.road) do
              [] ->
                Logger.debug(
                  "No dispatcher to send the ticket to (for vehicle #{ticket.plate} for day #{inspect({day1, day2})})"
                )

                {[ticket | tickets_to_send], vehicles}

              [{pid, :dummy} | _] ->
                Logger.debug(
                  "A dispatcher to send the ticket to exists (for vehicle #{ticket.plate} for day #{inspect({day1, day2})})"
                )

                send(pid, {:send_ticket, ticket})

                vehicle = %Vehicle{
                  vehicle
                  | days_with_ticket:
                      vehicle.days_with_ticket |> MapSet.put(day1) |> MapSet.put(day2)
                }

                vehicles = Map.put(vehicles, vehicle.plate, vehicle)

                {tickets_to_send, vehicles}
            end
          else
            Logger.debug(
              "Vehicle #{vehicle.plate} has already a ticket for day #{inspect({day1, day2})}"
            )

            {tickets_to_send, vehicles}
          end
        end
      )

    schedule_tickets_send()
    {:noreply, %State{state | tickets_to_send: tickets_to_send, vehicles: vehicles}}
  end

  # -- Private

  defp schedule_tickets_send() do
    Process.send_after(self(), :send_tickets, 1_000)
  end
end
