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
            IO.puts("MUERTO MATAO.")
            [&System.halt/1, false]

          behavioural_probability >= 70 ->
            [&Fib.fibonacci/1, false]

          behavioural_probability >= 50 ->
            [&Fib.of/1, false]

          behavioural_probability >= 30 ->
            IO.puts("Pérdida de envío.")
            [&Fib.fibonacci_tr/1, true]

          true ->
            [&Fib.fibonacci_tr/1, false]
        end
      else
        [op, false]
      end

    receive do
      {:req, {pid, args}} ->
        IO.puts("Nos ha llegado petición: con #{inspect(op)} el numero #{args}")

        if not omission do
          send(pid, op.(args))
          IO.puts("Enviando a proxy...")
        end

        IO.puts("Ejecuto con #{inspect(op)} el numero #{args}")
    end

    worker(new_op, rem(service_count + 1, k), k)
  end
end

defmodule Cliente do
  defp launch(pid, 1, mapa, nEnvio) do
    mapa = Map.put(mapa, nEnvio, Time.utc_now())
    send(pid, {self, 1500, nEnvio})

    receive do
      {:result, l, nPaquete} ->
        t1 = Map.get(mapa, nPaquete)
        tFinal = Time.diff(Time.utc_now(), t1, :microsecond)

        IO.puts(
          "Envio #{nPaquete} ha tardado #{inspect(tFinal)} microseconds y su valor es #{
            inspect(l)
          }"
        )
    end

    mapa
  end

  defp launch(pid, n, mapa, nEnvio) when n != 1 do
    number = if rem(n, 3) == 0, do: 100, else: 36
    mapa = Map.put(mapa, nEnvio, Time.utc_now())
    send(pid, {self, :random.uniform(number), nEnvio})
    launch(pid, n - 1, mapa, nEnvio + 1)
  end

  def genera_workload(server_pid, mapa, nEnvio) do
    mapa = launch(server_pid, 6 + :random.uniform(2), mapa, nEnvio)
    Process.sleep(2000 + :random.uniform(200))
    genera_workload(server_pid, mapa, nEnvio + 8)
  end
end
