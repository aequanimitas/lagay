defmodule Lagay do
  @moduledoc """
  The server
  """
  def start(client_pid) do
    __MODULE__
    |> spawn(:init, [client_pid])
    |> Process.register(:lagay)
  end

  def init(client_pid) do
    start_timer(client_pid)
    loop()
  end

  def loop do
    receive do
      {:timeout, timer_ref, {:interval, client_pid}} ->
        reading = %{
          time: fmt_localtime,
          proc_count: :erlang.system_info(:process_count),
          proc_limit: :erlang.system_info(:process_limit),
          queues: message_queue(),
          memory: mem_usage()
        }
        send(client_pid, {self(), :meter_reading, reading})
        start_timer(client_pid)
        loop()
    end
  end

  def fmt_localtime do
    {{y, mm, d}, {h, m, s}} = :erlang.localtime
    "#{h}/#{mm}/#{d} #{h}:#{m}:#{s}"
  end

  def mem_usage do
    :erlang.memory
    |> Enum.reduce([], fn {k, v}, acc ->
      v = (v / :math.pow(1024, 2)) |> Float.round(2)
      [{k, v} | acc]
    end)
  end

  def message_queue do
    Process.list
    |> Enum.map(fn proc ->
      case Process.info(proc, :message_queue_len) do
        :undefined -> {proc, :undefined}
        {:message_queue_len, count} -> {proc, count}
      end
    end)

  end

  def start_timer(client_pid) do
    :erlang.start_timer(5_000, self(), {:interval, client_pid})
  end

  defmodule Client do
    def start do
      pid = spawn(__MODULE__, :init, [])
      pid |> Process.register(__MODULE__)

      pid
    end

    def init do
      :queue.new()
      |> loop()
    end

    def terminate

    def call(name, msg) do
      send(name, {self(), :request, msg})
      receive do
        {:reply, reply} ->
          reply
      end
    end

    def reply(from, reply), do: send(from, {:reply, reply})

    ## Helpers
    def stat, do: call(__MODULE__, :stat)
    def recent, do: call(__MODULE__, :recent)

    def loop(queue) do
      receive do
        {from, :meter_reading, message} ->
          message
          |> :queue.in(queue)
          |> loop()
        {from, :request, message} ->
          {reply, new_queue} = handle_msg(message, queue)
          reply(from, reply)
          loop(new_queue)
        message ->
          # handle_info should be here
          loop(queue)
      end
    end

    def handle_msg(:stat, queue), do: {queue, queue}
    def handle_msg(:recent, queue), do: {:queue.peek(queue), queue}
  end
end
