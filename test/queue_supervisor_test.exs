defmodule Verk.QueueSupervisorTest do
  use ExUnit.Case, async: true
  import Verk.Queue.Supervisor

  describe "init/1" do
    test "defines tree" do
      {:ok, {_, children}} = init([:default, 25])
      [queue_manager, pool, workers_manager] = children

      assert %{id: :"default.queue_manager", type: :worker, modules: [Verk.QueueManager]} =
               queue_manager

      assert %{id: :"default.pool", type: :worker, modules: [:poolboy]} = pool

      assert %{id: :"default.workers_manager", type: :worker, modules: [Verk.WorkersManager]} =
               workers_manager
    end
  end

  describe "name/1" do
    test "returns supervisor name" do
      assert name("default") == :"default.supervisor"
    end
  end

  describe "child_spec/2" do
    test "returns supervisor spec" do
      assert %{
               id: :"default.supervisor",
               start: {Verk.Queue.Supervisor, :start_link, [:default, 25]},
               shutdown: :infinity,
               type: :supervisor,
               modules: [Verk.Queue.Supervisor]
             } = child_spec(:default, 25)
    end
  end
end
