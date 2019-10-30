# AUTORES: Juan José Tambo, Pedro Tamargo
# NIAs: 755742, 758267
# FICHERO: escenario3.exs
# FECHA: 15/10/19
# TIEMPO: 10 minutos
# DESCRIPCION: Se desarrolla arquitectura Máster-worker, con pool de workers. La lista de workers a usar es variable.

import Fib

defmodule Servidor do
  def server(dir_pool) do
    Process.register(self(),:master)
    server_p(dir_pool)
  end

  defp server_p(dir_pool) do
    pid_pool = {:pool, dir_pool}
    # Escuchamos peticiones del cliente
    {client, op, limits,time, nEnvio} =
      receive do
        {client, op, limits,time,nEnvio} -> {client, op, limits,time,nEnvio}
      end

    spawn(
      Servidor,
      :comunicar,
      [client, pid_pool, op, Enum.to_list(limits),time,nEnvio]
    )

    server_p(dir_pool)
  end

  def comunicar(pid_client, pool, op, lista,time,nEnvio) do
    # Pide worker al pool
    send(
      pool,
      {:peti, self()}
    )

    # Recibimos el worker con el que trabajaremos
    pid_w =
      receive do
        {:ok, pid_w} -> pid_w
      end

    # Generamos el proceso en el nodo y guardamos resultado en la variable resutl

    Node.spawn(
      pid_w,
      Worker,
      :worker,
      [self(), pid_w, pool, op, lista]
    )

    result =
      receive do
        result -> result
      end

    send(
      pid_client,
      {:fin, result,time,nEnvio}
    )
  end
end

defmodule Pool do
  def pool() do
    Process.register(self(),:pool)
    lista_disponibles = [
      :"w1@155.210.154.198",
      :"w1@155.210.154.198",
      :"w1@155.210.154.198",
      :"w1@155.210.154.198"
    ]

    lista_ocupados = []
    lista_pendientes = []

    pool(lista_disponibles, lista_ocupados, lista_pendientes)
  end

  defp pool(disp, ocu, pend) do
    # Esperamos una peticion del master
    {disp, ocu, pend} =
      receive do
        {:peti, pid} ->
          if disp != [] do
            [head | tail] = disp
            disp = tail

            # Marcamos al worker que enviamos como ocupado
            ocu = ocu ++ [head]
            # Enviamos un worker al master
            send(
              pid,
              {:ok, head}
            )

            {disp, ocu, pend}
          else
            pend = pend ++ [pid]
            {disp, ocu, pend}
          end

        {:fin, pid} ->
          # Fin de worker -> anadimos a disponible
          # Comprobamos si hay alguien esperando        
          if pend != [] do
            # Existe alguien esperando -> Le damos servicio
            [pid_pendiente | resto] = pend
            pend = resto

            send(
              pid_pendiente,
              {:ok, pid}
            )

            {disp, ocu, pend}
          else
            # Lo devolvemos a la lista de disponibles
            ocu = ocu -- [pid]
            disp = disp ++ [pid]
            {disp, ocu, pend}
          end
      end

    pool(disp, ocu, pend)
  end
end

defmodule Worker do
  def worker(pid_master, pid_w, pid_p, op, lista) do
    # Miramos peticion
    result =
      cond do
        op == :fib -> Enum.map(lista, fn x -> Fib.fibonacci(x) end)
        op == :fib_tr -> Enum.map(lista, fn x -> Fib.fibonacci_tr(x) end)
        op == :of -> Enum.map(lista, fn x -> Fib.of(x) end)
      end

    # Nos ponemos disponibles

    send(
      pid_p,
      {:fin, pid_w}
    )

    # Devolvemos resultado -> Enviando a master
    send(
      pid_master,
      result
    )
  end
end
