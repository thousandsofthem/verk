defmodule IntegrationTest do
  use ExUnit.Case
  alias Verk.Events.{QueueRunning, QueuePausing, QueuePaused}

  defmodule Consumer do
    use GenStage

    def start(), do: GenStage.start(__MODULE__, self())

    def init(parent) do
      filter = fn event -> event.__struct__ in [QueueRunning, QueuePausing, QueuePaused] end
      {:consumer, parent, subscribe_to: [{Verk.EventProducer, selector: filter}]}
    end

    def handle_events(events, _from, parent) do
      Enum.each(events, fn event -> send(parent, event) end)
      {:noreply, [], parent}
    end
  end

  setup do
    Application.put_env(:verk, :generate_node_id, false, persistent: true)
    Application.delete_env(:verk, :local_node_id, persistent: true)
    {:ok, redis} = Redix.start_link(Confex.get_env(:verk, :redis_url))
    Redix.command!(redis, ["FLUSHDB"])
    {:ok, redis: redis}
  end

  defp enqueue_jobs!(redis) do
    for _x <- 0..10 do
      Verk.enqueue(
        %Verk.Job{queue: "queue_one", class: Integration.SleepWorker, args: [1_500]},
        redis
      )

      Verk.enqueue(
        %Verk.Job{queue: "queue_two", class: Integration.SleepWorker, args: [2_000]},
        redis
      )
    end
  end

  @tag integration: true
  test "shutdown gracefully stops queues", %{redis: redis} do
    enqueue_jobs!(redis)

    Application.ensure_all_started(:integration)
    {:ok, _consumer} = Consumer.start()
    assert Redix.command!(redis, ["SMEMBERS", "verk_nodes"]) == []
    Application.stop(:integration)

    assert_receive %Verk.Events.QueuePausing{queue: :queue_one}
    assert_receive %Verk.Events.QueuePausing{queue: :queue_two}
    assert_receive %Verk.Events.QueuePaused{queue: :queue_one}
    assert_receive %Verk.Events.QueuePaused{queue: :queue_two}
  end

  @tag integration: true
  test "generate_node_id true maintains verk_nodes", %{redis: redis} do
    enqueue_jobs!(redis)

    Application.put_env(:verk, :generate_node_id, true, persistent: true)
    Application.ensure_all_started(:integration)
    {:ok, _consumer} = Consumer.start()
    node_id = Application.fetch_env!(:verk, :local_node_id)
    assert Redix.command!(redis, ["SMEMBERS", "verk_nodes"]) == [node_id]
    assert Redix.command!(redis, ["TTL", "verk:node:#{node_id}"]) > 0

    Application.stop(:integration)

    assert_receive %Verk.Events.QueuePausing{queue: :queue_one}
    assert_receive %Verk.Events.QueuePausing{queue: :queue_two}
    assert_receive %Verk.Events.QueuePaused{queue: :queue_one}
    assert_receive %Verk.Events.QueuePaused{queue: :queue_two}
  end

  defp wait_for(fun, timeout \\ 5_000) do
    deadline = System.monotonic_time(:millisecond) + timeout

    Stream.repeatedly(fn ->
      fun.() || (Process.sleep(50) && nil)
    end)
    |> Enum.find(fn result ->
      result || System.monotonic_time(:millisecond) > deadline
    end)
  end

  @tag integration: true
  test "runs a job stored in verk 1.7.3's format", %{redis: redis} do
    Process.register(self(), :integration_test)
    on_exit(fn -> Application.stop(:integration) end)

    # payload exactly as verk 1.7.3 enqueues it (args is a JSON-encoded string)
    payload =
      ~s({"args":"[\\"legacy\\"]","queue":"queue_one","max_retry_count":3,) <>
        ~s("class":"Elixir.Integration.NotifyWorker","jid":"1112872072447533835",) <>
        ~s("enqueued_at":1795532236,"finished_at":null,"failed_at":null,"error_message":null,) <>
        ~s("retry_count":0,"retried_at":null,"created_at":null,"error_backtrace":null})

    Redix.command!(redis, ["LPUSH", "queue:queue_one", payload])
    Application.ensure_all_started(:integration)

    assert_receive {:ran, "legacy"}, 5_000
  end

  @tag integration: true
  test "failed jobs keep their backtrace in the retry set, then go dead", %{redis: redis} do
    on_exit(fn -> Application.stop(:integration) end)
    Application.ensure_all_started(:integration)

    {:ok, _} =
      Verk.enqueue(
        %Verk.Job{queue: "queue_one", class: Integration.FailWorker, args: ["r"], max_retry_count: 1},
        redis
      )

    {:ok, _} =
      Verk.enqueue(
        %Verk.Job{queue: "queue_two", class: Integration.FailWorker, args: ["d"], max_retry_count: 0},
        redis
      )

    retried = wait_for(fn -> Redix.command!(redis, ["ZRANGE", "retry", "0", "-1"]) |> List.first() end)
    assert retried, "job never reached the retry set"
    retried = Jason.decode!(retried)
    assert retried["error_message"] =~ "integration failure r"
    assert retried["error_backtrace"] =~ "Integration.FailWorker.perform/1"

    dead = wait_for(fn -> Redix.command!(redis, ["ZRANGE", "dead", "0", "-1"]) |> List.first() end)
    assert dead, "job never reached the dead set"
    assert Jason.decode!(dead)["error_message"] =~ "integration failure d"
  end
end
