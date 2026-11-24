Mimic.copy(Verk.Time)
Mimic.copy(:poolboy)
Mimic.copy(Supervisor)
Mimic.copy(Redix)
Mimic.copy(Verk)
Mimic.copy(Verk.Job)
Mimic.copy(Verk.Scripts)
Mimic.copy(Verk.InProgressQueue)
Mimic.copy(Verk.RetrySet)
Mimic.copy(Verk.DeadSet)
Mimic.copy(Verk.SortedSet)
Mimic.copy(Verk.Manager)
Mimic.copy(Verk.Node)
Mimic.copy(Verk.WorkersManager)
Mimic.copy(Verk.Manager.Supervisor)
Mimic.copy(Verk.QueueManager)
Mimic.copy(Verk.Log)
Mimic.copy(Verk.Worker)

defmodule Verk.TestHelpers do
  @moduledoc false
  # Processes linked to a finished test die asynchronously, so a registered name
  # can still be taken when the next test starts its own copy.
  def await_unregistered(name, timeout \\ 1_000) do
    case Process.whereis(name) do
      nil ->
        :ok

      pid ->
        ref = Process.monitor(pid)

        receive do
          {:DOWN, ^ref, _, _, _} -> :ok
        after
          timeout -> raise "#{inspect(name)} still registered after #{timeout}ms"
        end
    end
  end
end

ExUnit.start()
ExUnit.configure(exclude: [integration: true])
