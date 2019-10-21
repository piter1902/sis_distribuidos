# AUTORES: nombres y apellidos
# NIAs: números de identificacion de los alumnos
# FICHERO: nombre del fichero
# FECHA: fecha de realizacion
# TIEMPO: tiempo en horas de codificación
# DESCRIPCION: breve descripcion del contenido del fichero

import Fib

defmodule Servidor do
  def server() do
    lista_disponibles = [
      :"worker@127.0.0.1",
      :"worker@127.0.0.1",
      :"worker@127.0.0.1",
      :"worker@127.0.0.1"
    ]

    lista_ocupados = []
    lista_pendientes = []
    server(lista_disponibles, lista_ocupados, lista_pendientes)
  end

  def server(disp, ocu, pend) do
    # pid_pool = {:pool, :"pool@127.0.0.1"}
    # Escuchamos peticiones del cliente
    {disp, ocu, pend} =
      receive do
        {client, op, limits} ->
          if disp != [] do
            [head | tail] = disp
            disp = tail
            ocu = ocu ++ [head]

            spawn(
              Servidor,
              :comunicar,
              [self(), head, client, op, limits]
            )

            {disp, ocu, pend}
          else
            pend = pend ++ [{client, op, limits}]

            {disp, ocu, pend}
          end

        {:fin, pid_w} ->
          if pend != [] do
            # Existe alguien esperando -> Le damos servicio
            [pid_pendiente | resto] = pend
            pend = resto
            {cliente, op, limits} = pid_pendiente

            spawn(
              Servidor,
              :comunicar,
              [self(), pid_w, cliente, op, limits]
            )

            {disp, ocu, pend}
          else
            # Lo devolvemos a la lista de disponibles
            ocu = ocu -- [pid_w]
            disp = disp ++ [pid_w]
            {disp, ocu, pend}
          end
      end

    server(disp, ocu, pend)
  end

  def comunicar(pid_server, pid_w, pid_client, op, limits) do
    Worker.worker(self(), pid_w, pid_server, op, Enum.to_list(limits))

    result =
      receive do
        result -> result
      end

    send(
      pid_client,
      {:fin, result}
    )
  end
end

defmodule Worker do
  def worker(pid_thread, pid_w, pid_master, op, lista) do
    # Miramos peticion

    result =
      cond do
        op == :fib -> Enum.map(lista, fn x -> Fib.fibonacci(x) end)
        op == :fib_tr -> Enum.map(lista, fn x -> Fib.fibonacci_tr(x) end)
        op == :of -> Enum.map(lista, fn x -> Fib.of(x) end)
      end

    # Nos ponemos disponibles

    send(
      pid_master,
      {:fin, pid_w}
    )

    # Devolvemos resultado -> Enviando a thread
    send(
      pid_thread,
      result
    )
  end
end