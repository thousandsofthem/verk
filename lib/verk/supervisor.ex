defmodule Verk.Supervisor do
  @moduledoc """
  Supervisor definition for Verk application. It consists of:

    * `Verk.ScheduleManager`
    * GenStage producer named `Verk.EventProducer`
    * GenStage consumer `Verk.QueueStats`
    * Redis connectionn named `Verk.Redis`
    * A `Verk.Queue.Supervisor` per queue
  """
  use Supervisor

  @doc """
  It starts the main supervisor
  """
  def start_link(_ \\ []) do
    Supervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc false
  def init(_) do
    local_verk_node_id = verk_node_id()

    Application.put_env(:verk, :local_node_id, local_verk_node_id)

    Supervisor.init(children(), strategy: :one_for_one)
  end

  defp children do
    redis_url = Confex.get_env(:verk, :redis_url)
    shutdown_timeout = Confex.get_env(:verk, :shutdown_timeout, 30_000)
    generate_node_id = Confex.get_env(:verk, :generate_node_id)

    redis = Verk.ChildSpec.worker(Verk.Redis, Redix, [redis_url, [name: Verk.Redis]])
    event_producer = Verk.ChildSpec.worker(Verk.EventProducer, Verk.EventProducer, [])
    queue_stats = Verk.ChildSpec.worker(Verk.QueueStats, Verk.QueueStats, [])
    schedule_manager = Verk.ChildSpec.worker(Verk.ScheduleManager, Verk.ScheduleManager, [])
    manager_sup = Verk.ChildSpec.supervisor(Verk.Manager.Supervisor, Verk.Manager.Supervisor, [])

    drainer =
      Verk.ChildSpec.worker(Verk.QueuesDrainer, Verk.QueuesDrainer, [shutdown_timeout],
        shutdown: shutdown_timeout
      )

    children = [
      redis,
      event_producer,
      queue_stats,
      schedule_manager,
      manager_sup,
      drainer
    ]

    if generate_node_id do
      node_manager = Verk.ChildSpec.worker(Verk.Node.Manager, Verk.Node.Manager, [])

      List.insert_at(children, 1, node_manager)
    else
      children
    end
  end

  defp verk_node_id do
    case Application.fetch_env(:verk, :local_node_id) do
      {:ok, local_verk_node_id} ->
        local_verk_node_id

      :error ->
        if Confex.get_env(:verk, :generate_node_id, false) do
          <<part1::32, part2::32>> = :crypto.strong_rand_bytes(8)
          "#{part1}#{part2}"
        else
          Confex.get_env(:verk, :node_id, "1")
        end
    end
  end
end
