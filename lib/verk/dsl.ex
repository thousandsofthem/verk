defmodule Verk.Dsl do
  @moduledoc false

  @doc """
  Creates bang version of given function.
  """
  defmacro bangify(result) do
    quote do
      Verk.Dsl.unwrap!(unquote(result))
    end
  end

  # A function rather than inline clauses: callers return only some of these
  # shapes, and inlined unreachable clauses trip the compiler's type checks.
  @doc false
  def unwrap!(:ok), do: nil
  def unwrap!({:ok, value}), do: value
  def unwrap!({:error, error}), do: raise(error)
end
