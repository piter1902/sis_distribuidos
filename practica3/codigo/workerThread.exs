defmodule Fib do
  def fibonacci(0), do: 0
  def fibonacci(1), do: 1

  def fibonacci(n) when n >= 2 do
    fibonacci(n - 2) + fibonacci(n - 1)
  end

  def fibonacci_tr(n), do: fibonacci_tr(n, 0, 1)
  defp fibonacci_tr(0, _acc1, _acc2), do: 0
  defp fibonacci_tr(1, _acc1, acc2), do: acc2

  defp fibonacci_tr(n, acc1, acc2) do
    fibonacci_tr(n - 1, acc2, acc1 + acc2)
  end

  @golden_n :math.sqrt(5)
  def of(n) do
    (x_of(n) - y_of(n)) / @golden_n
  end

  defp x_of(n) do
    :math.pow((1 + @golden_n) / 2, n)
  end

  def y_of(n) do
    :math.pow((1 - @golden_n) / 2, n)
  end
end

defmodule Worker do
  def init do
    Process.sleep(10000)
    worker(&Fib.fibonacci_tr/1, 0, :random.uniform(10))
  end

  defp worker(op, service_count, k) do
    [new_op, omission] =
      if rem(service_count, k) == 0 do
        behavioural_probability = :random.uniform(100)

        cond do
          behavioural_probability >= 90 ->
            [&System.halt/1, false]

          behavioural_probability >= 70 ->
            [&Fib.fibonacci/1, false]

          behavioural_probability >= 50 ->
            [&Fib.of/1, false]

          behavioural_probability >= 30 ->
            [&Fib.fibonacci_tr/1, true]

          true ->
            [&Fib.fibonacci_tr/1, false]
        end
      else
        [op, false]
      end

    receive do
      {:req, {pid, args}} -> if not omission, do: send(pid, op.(args))
    end

    worker(new_op, rem(service_count + 1, k), k)
  end
end

defmodule Cliente do
  def server_mapa(mapa) do
    mapa =
      receive do
        {:set, where, value} ->
          Map.put(mapa, where, value)

        {:get, pid} ->
          send(
            pid,
            {:get_reply, mapa}
          )

          mapa
      end

    server_mapa(mapa)
  end

  def escucha(server_mapa) do
    receive do
      {:result, l, nPaquete} ->
        send(
          server_mapa,
          {:get, self}
        )

        mapa =
          receive do
            {:get_reply, mapa} -> mapa
          end

        t1 = Map.get(mapa, nPaquete)
        tFinal = Time.diff(Time.utc_now(), t1, :microsecond)
        # IO.puts("Tiempo ahora #{inspect(Time.utc_now())} y tiempo inicial #{inspect(t1)}")

        IO.puts(
          "Envio #{nPaquete} ha tardado #{inspect(tFinal)} microseconds y su valor es #{
            inspect(l)
          }"
        )

        # IO.inspect(l)
    end

    escucha(server_mapa)
  end

  defp launch(pid, 1, nenvio, pid_server, pid_escucha) do
    send(
      pid_server,
      {:set, nenvio, Time.utc_now()}
    )

    send(pid, {pid_escucha, 1500, nenvio})
  end

  defp launch(pid, n, nenvio, pid_server, pid_escucha) when n != 1 do
    number = if rem(n, 3) == 0, do: 100, else: 36
    # IO.puts("Introduzco en #{nenvio} el tiempo #{inspect(Time.utc_now())}")

    send(
      pid_server,
      {:set, nenvio, Time.utc_now()}
    )

    send(pid, {pid_escucha, :random.uniform(number), nenvio})
    launch(pid, n - 1, nenvio + 1, pid_server, pid_escucha)
  end

  defp genera_workload(server_pid, nEnvio, pid_server, pid_escucha) do
    launch(server_pid, 6 + :random.uniform(2), nEnvio, pid_server, pid_escucha)
    Process.sleep(2000 + :random.uniform(200))
    genera_workload(server_pid, nEnvio + 8, pid_server, pid_escucha)
  end

  def init(server_pid) do
    pid_server =
      spawn(
        Cliente,
        :server_mapa,
        [Map.new()]
      )

    pid_escucha =
      spawn(
        Cliente,
        :escucha,
        [pid_server]
      )

    genera_workload(server_pid, 0, pid_server, pid_escucha)
  end
end
