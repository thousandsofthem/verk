defmodule Integration.NotifyWorker do
  @moduledoc false
  # jobs carry only JSON args, so report to a registered test process
  def perform(tag), do: send(:integration_test, {:ran, tag})
end

defmodule Integration.FailWorker do
  @moduledoc false
  def perform(tag), do: raise("integration failure #{tag}")
end
