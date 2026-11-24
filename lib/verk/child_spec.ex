defmodule Verk.ChildSpec do
  @moduledoc false
  # Map child specs with the defaults of the deprecated Supervisor.Spec.worker/3
  # and supervisor/3, so the supervision tree is unchanged.

  @doc false
  def worker(id, module, args, opts \\ []) do
    spec(id, module, args, :worker, 5000, opts)
  end

  @doc false
  def supervisor(id, module, args, opts \\ []) do
    spec(id, module, args, :supervisor, :infinity, opts)
  end

  defp spec(id, module, args, type, shutdown, opts) do
    %{
      id: id,
      start: {module, :start_link, args},
      restart: Keyword.get(opts, :restart, :permanent),
      shutdown: Keyword.get(opts, :shutdown, shutdown),
      type: type,
      modules: [module]
    }
  end
end
