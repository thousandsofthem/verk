defmodule Verk.Log do
  @moduledoc """
  Helper module to log when a job starts, fails or finishes.
  """

  require Logger
  import Logger
  alias Verk.{Job, Time}

  def start(%Job{jid: job_id, class: module}, process_id) do
    :verk
    |> Confex.get_env(:start_job_log_level, :info)
    |> level()
    |> log("#{module} #{job_id} start", process_id: inspect(process_id))
  end

  def done(%Job{jid: job_id, class: module}, start_time, process_id) do
    :verk
    |> Confex.get_env(:done_job_log_level, :info)
    |> level()
    |> log(
      "#{module} #{job_id} done: #{elapsed_time(start_time)}",
      process_id: inspect(process_id)
    )
  end

  def fail(%Job{jid: job_id, class: module}, start_time, process_id) do
    :verk
    |> Confex.get_env(:fail_job_log_level, :info)
    |> level()
    |> log(
      "#{module} #{job_id} fail: #{elapsed_time(start_time)}",
      process_id: inspect(process_id)
    )
  end

  # :warn is deprecated in Elixir's Logger; keep accepting it from existing configs
  defp level(:warn), do: :warning
  defp level(level), do: level

  defp elapsed_time(start_time) do
    now = Time.now()

    if Time.diff(start_time, now, :second) == 0 do
      milliseconds_diff = Time.diff(start_time, now, :millisecond)
      "#{trunc(milliseconds_diff)} ms"
    else
      "#{trunc(Time.diff(start_time, now))} s"
    end
  end
end
