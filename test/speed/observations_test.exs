defmodule Protohackers.Speed.ObservationsTest do
  use ExUnit.Case, async: true

  alias Protohackers.Speed.Message.{Camera, Plate}
  alias Protohackers.Speed.{Observation, Observations}

  test "insert observation in empty list" do
    plate = %Plate{plate: "FUBAR", timestamp: 1}
    camera = %Camera{road: 1, mile: 1, limit: 100}

    observations = Observations.insert_observation([], [], plate, camera)

    assert observations == [Observation.new(plate, camera)]
  end

  test "insert 2 observations in empty list" do
    plate_1 = %Plate{plate: "FUBAR", timestamp: 1}
    camera_1 = %Camera{road: 1, mile: 1, limit: 100}

    plate_2 = %Plate{plate: "FUBAR", timestamp: 2}
    camera_2 = %Camera{road: 1, mile: 2, limit: 100}

    observations = Observations.insert_observation([], [], plate_1, camera_1)
    observations = Observations.insert_observation([], observations, plate_2, camera_2)

    assert observations == [
             Observation.new(plate_1, camera_1),
             Observation.new(plate_2, camera_2)
           ]
  end

  test "insert observation at the beginning of an existing list" do
    plate_1 = %Plate{plate: "FUBAR", timestamp: 1}
    camera_1 = %Camera{road: 1, mile: 1, limit: 100}

    plate_2 = %Plate{plate: "FUBAR", timestamp: 2}
    camera_2 = %Camera{road: 1, mile: 2, limit: 100}

    plate_3 = %Plate{plate: "FUBAR", timestamp: 3}
    camera_3 = %Camera{road: 1, mile: 3, limit: 100}

    plate_4 = %Plate{plate: "FUBAR", timestamp: 4}
    camera_4 = %Camera{road: 1, mile: 4, limit: 100}

    observations = [
      Observation.new(plate_2, camera_2),
      Observation.new(plate_3, camera_3),
      Observation.new(plate_4, camera_4)
    ]

    observations = Observations.insert_observation([], observations, plate_1, camera_1)

    assert observations == [
             Observation.new(plate_1, camera_1),
             Observation.new(plate_2, camera_2),
             Observation.new(plate_3, camera_3),
             Observation.new(plate_4, camera_4)
           ]
  end

  test "insert observation in middle of an existing list" do
    plate_1 = %Plate{plate: "FUBAR", timestamp: 1}
    camera_1 = %Camera{road: 1, mile: 1, limit: 100}

    plate_2 = %Plate{plate: "FUBAR", timestamp: 2}
    camera_2 = %Camera{road: 1, mile: 2, limit: 100}

    plate_3 = %Plate{plate: "FUBAR", timestamp: 3}
    camera_3 = %Camera{road: 1, mile: 3, limit: 100}

    plate_4 = %Plate{plate: "FUBAR", timestamp: 4}
    camera_4 = %Camera{road: 1, mile: 4, limit: 100}

    observations = [
      Observation.new(plate_1, camera_1),
      Observation.new(plate_3, camera_3),
      Observation.new(plate_4, camera_4)
    ]

    observations = Observations.insert_observation([], observations, plate_2, camera_2)

    assert observations == [
             Observation.new(plate_1, camera_1),
             Observation.new(plate_2, camera_2),
             Observation.new(plate_3, camera_3),
             Observation.new(plate_4, camera_4)
           ]
  end

  test "insert observation in middle of an existing list (2)" do
    plate_1 = %Plate{plate: "FUBAR", timestamp: 1}
    camera_1 = %Camera{road: 1, mile: 1, limit: 100}

    plate_2 = %Plate{plate: "FUBAR", timestamp: 2}
    camera_2 = %Camera{road: 1, mile: 2, limit: 100}

    plate_3 = %Plate{plate: "FUBAR", timestamp: 3}
    camera_3 = %Camera{road: 1, mile: 3, limit: 100}

    plate_4 = %Plate{plate: "FUBAR", timestamp: 4}
    camera_4 = %Camera{road: 1, mile: 4, limit: 100}

    observations = [
      Observation.new(plate_1, camera_1),
      Observation.new(plate_2, camera_2),
      Observation.new(plate_4, camera_4)
    ]

    observations = Observations.insert_observation([], observations, plate_3, camera_3)

    assert observations == [
             Observation.new(plate_1, camera_1),
             Observation.new(plate_2, camera_2),
             Observation.new(plate_3, camera_3),
             Observation.new(plate_4, camera_4)
           ]
  end

  test "insert observation at the end of an existing list" do
    plate_1 = %Plate{plate: "FUBAR", timestamp: 1}
    camera_1 = %Camera{road: 1, mile: 1, limit: 100}

    plate_2 = %Plate{plate: "FUBAR", timestamp: 2}
    camera_2 = %Camera{road: 1, mile: 2, limit: 100}

    plate_3 = %Plate{plate: "FUBAR", timestamp: 3}
    camera_3 = %Camera{road: 1, mile: 3, limit: 100}

    plate_4 = %Plate{plate: "FUBAR", timestamp: 4}
    camera_4 = %Camera{road: 1, mile: 4, limit: 100}

    observations = [
      Observation.new(plate_1, camera_1),
      Observation.new(plate_2, camera_2),
      Observation.new(plate_3, camera_3)
    ]

    observations = Observations.insert_observation([], observations, plate_4, camera_4)

    assert observations == [
             Observation.new(plate_1, camera_1),
             Observation.new(plate_2, camera_2),
             Observation.new(plate_3, camera_3),
             Observation.new(plate_4, camera_4)
           ]
  end
end
