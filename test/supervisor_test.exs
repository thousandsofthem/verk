defmodule Verk.SupervisorTest do
  use ExUnit.Case
  import Verk.Supervisor

  setup do
    Application.delete_env(:verk, :local_node_id)
    Application.delete_env(:verk, :generate_node_id)
    Application.put_env(:verk, :node_id, "123")

    on_exit(fn ->
      Application.delete_env(:verk, :node_id)
      Application.delete_env(:verk, :local_node_id)
      Application.delete_env(:verk, :generate_node_id)
    end)

    :ok
  end

  describe "init/1" do
    test "defines tree" do
      {:ok, {_, children}} = init([])
      [redix, producer, stats, schedule_manager, manager_sup, drainer] = children

      assert %{id: Verk.Redis, type: :worker, modules: [Redix]} = redix
      assert %{id: Verk.EventProducer, type: :worker, modules: [Verk.EventProducer]} = producer
      assert %{id: Verk.QueueStats, type: :worker, modules: [Verk.QueueStats]} = stats

      assert %{id: Verk.ScheduleManager, type: :worker, modules: [Verk.ScheduleManager]} =
               schedule_manager

      assert %{id: Verk.Manager.Supervisor, type: :supervisor, modules: [Verk.Manager.Supervisor]} =
               manager_sup

      assert %{id: Verk.QueuesDrainer, type: :worker, modules: [Verk.QueuesDrainer]} = drainer
      # the drainer gets the whole shutdown_timeout to let running jobs finish
      assert drainer.shutdown == Confex.get_env(:verk, :shutdown_timeout, 30_000)
      assert %{shutdown: :infinity} = manager_sup
    end

    test "defines local_node_id randomly if generate_node_id is true" do
      Application.put_env(:verk, :generate_node_id, true)
      assert {:ok, _} = init([])
      assert Application.get_env(:verk, :local_node_id) != "123"
    end

    test "defines local_node_id as node_id if generate_node_id is false" do
      Application.put_env(:verk, :generate_node_id, false)
      assert {:ok, _} = init([])
      assert Application.get_env(:verk, :local_node_id) == "123"
    end

    test "does nothing if node_id if local_node_id is already defined" do
      Application.put_env(:verk, :generate_node_id, true)
      Application.put_env(:verk, :local_node_id, "456")
      assert {:ok, _} = init([])
      assert Application.get_env(:verk, :local_node_id) == "456"
    end

    test "defines tree with node manager if generate_node_id is true" do
      Application.put_env(:verk, :generate_node_id, true)

      {:ok, {_, children}} = init([])
      [redix, node_manager, producer, stats, schedule_manager, manager_sup, drainer] = children

      assert %{id: Verk.Redis, type: :worker, modules: [Redix]} = redix
      assert %{id: Verk.Node.Manager, type: :worker, modules: [Verk.Node.Manager]} = node_manager
      assert %{id: Verk.EventProducer, type: :worker, modules: [Verk.EventProducer]} = producer
      assert %{id: Verk.QueueStats, type: :worker, modules: [Verk.QueueStats]} = stats

      assert %{id: Verk.ScheduleManager, type: :worker, modules: [Verk.ScheduleManager]} =
               schedule_manager

      assert %{id: Verk.Manager.Supervisor, type: :supervisor, modules: [Verk.Manager.Supervisor]} =
               manager_sup

      assert %{id: Verk.QueuesDrainer, type: :worker, modules: [Verk.QueuesDrainer]} = drainer
    end
  end
end
