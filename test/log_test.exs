defmodule Verk.LogTest do
  # changes :verk app env in one test
  use ExUnit.Case, async: false
  import ExUnit.CaptureLog

  alias Verk.Time

  describe "start/2" do
    test "logs start" do
      worker = self()
      job = %Verk.Job{}

      assert capture_log(fn -> Verk.Log.start(job, worker) end) =~ ~r/start/
    end
  end

  describe "done/3" do
    test "logs done with time in milliseconds" do
      worker = self()
      job = %Verk.Job{}
      start_time = Verk.Time.now()

      assert capture_log(fn ->
               Verk.Log.done(job, start_time, worker)
             end) =~ ~r/done: \d+ ms/
    end

    test "logs done with time in seconds" do
      worker = self()
      job = %Verk.Job{}

      start_time =
        Verk.Time.now()
        |> Verk.Time.shift(-2)

      assert capture_log(fn ->
               Verk.Log.done(job, start_time, worker)
             end) =~ ~r/done: \d+ s/
    end
  end

  describe "deprecated :warn level" do
    setup do
      Application.put_env(:verk, :fail_job_log_level, :warn)
      on_exit(fn -> Application.delete_env(:verk, :fail_job_log_level) end)
    end

    test "is logged as :warning" do
      log =
        capture_log([level: :warning], fn ->
          Verk.Log.fail(%Verk.Job{}, Verk.Time.now(), self())
        end)

      assert log =~ "[warning]"
      assert log =~ ~r/fail: \d+ ms/
    end
  end

  describe "fail/3" do
    test "logs fail with time in milliseconds" do
      worker = self()
      job = %Verk.Job{}
      start_time = Verk.Time.now()

      assert capture_log(fn ->
               Verk.Log.fail(job, start_time, worker)
             end) =~ ~r/fail: \d+ ms/
    end

    test "logs fail with time in seconds" do
      worker = self()
      job = %Verk.Job{}

      start_time =
        Verk.Time.now()
        |> Time.shift(-2, :second)

      assert capture_log(fn ->
               Verk.Log.fail(job, start_time, worker)
             end) =~ ~r/fail: \d+ s/
    end
  end
end
