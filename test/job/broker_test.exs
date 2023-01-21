defmodule Protohackers.Job.BrokerTest do
  use ExUnit.Case, async: true

  alias Protohackers.Job.Broker

  test "test" do
    assert {:ok, broker} = start_supervised(Broker)

    j1 = %{job: %{"title" => "j-zluNvpfh"}, pri: 900, queue: "q-5K7mFIBz"}
    j2 = %{job: %{"title" => "j-0wdvNk0s"}, pri: 8810, queue: "q-yimfzjo9"}

    Broker.put(broker, j1)
    Broker.put(broker, j2)

    req = %{
      queues: [
        "q-5K7mFIBz",
        "q-yimfzjo9"
      ],
      wait: false
    }

    {:ok, res1} = Broker.get(broker, req)
    {:ok, res2} = Broker.get(broker, req)

    assert res1 == %{
             id: 2,
             job: %{"title" => "j-0wdvNk0s"},
             pri: 8810,
             queue: "q-yimfzjo9",
             status: "ok"
           }

    assert res2 == %{
             id: 1,
             job: %{"title" => "j-zluNvpfh"},
             pri: 900,
             queue: "q-5K7mFIBz",
             status: "ok"
           }
  end
end
