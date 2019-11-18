# AUTORES: nombres y apellidos
# NIAs: números de identificacion de los alumnos
# FICHERO: nombre del fichero
# FECHA: fecha de realizacion
# TIEMPO: tiempo en horas de codificación
# DESCRIPCION: breve descripcion del contenido del fichero

import Fib

defmodule Servidor do
  def server(dir_pool) do
    Process.register(self(), :master)
    server_p(dir_pool)
  end

  defp server_p(dir_pool, proxy_machine) do
    pid_pool = {:pool, dir_pool}
    # Escuchamos peticiones del cliente
    {client, op, num, time, nEnvio} =
      receive do
        {client, op, num, time, nEnvio} -> {client, op, num, time, nEnvio}
      end

    # Creamos el proxy para comunicarnos con el worker
    Node.spawn(
      proxy_machine,
      Proxy,
      :proxy,
      [client, pid_pool, op, num, time, nEnvio]
    )

    server_p(dir_pool, proxy_machine)
  end

  defmodule Proxy do
    def proxy(pid_client, pool, op, num, time, nEnvio) do
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

      # Enviamos el mensaje al worker
      send(
        pid_w,
        {:req, {self(), num}}
      )

      # Esperamos al resultado -> con timeout
      result =
        receive do
          result -> result
        end

      # Gestion de errores
      # Devolvemos el worker al pool
      send(
        pool,
        {:ok, pid_w}
      )

      # Devolvemos el resultado al cliente
      # send(
      #   pid_client,
      #   {:fin, result, time, nEnvio}
      # )
      send(
        pid_client,
        {:result, result}
      )
    end
  end
end

defmodule Pool do
  def pool(lista_workers) do
    Process.register(self(), :pool)

    # lista_disponibles = [
    #   :"w1@155.210.154.198",
    #   :"w1@155.210.154.198",
    #   :"w1@155.210.154.198",
    #   :"w1@155.210.154.198"
    # ]

    lista_ocupados = []
    lista_pendientes = []

    pool(lista_workers, lista_ocupados, lista_pendientes)
  end

  # Mensajes que nos pueden llegar -> 
  #   :peti   -> peticion de worker
  #   :ok     -> peticion de fin de uso de worker (sin problemas)
  #   :fallo2 -> fallo de tipo2 ==> El nodo ha caido
  #   :fallo1 -> fallo de tipo1 ==> El nodo responde mal
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

            IO.puts("Disponibles ->")
            IO.puts(inspect(disp))
            {disp, ocu, pend}
          else
            pend = pend ++ [pid]
            IO.puts("Estamos en el caso de no disponibles -> pend = ")
            IO.puts(inspect(pend))
            {disp, ocu, pend}
          end

        {:ok, pid} ->
          IO.puts("Nos ha llegado peticion de fin del worker #{pid}")
          # Fin de worker -> anadimos a disponible
          # Comprobamos si hay alguien esperando        
          if pend != [] do
            IO.puts("Hay algun pendiente despues de dejar worker.")
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
            IO.puts("No hay ningun pendiente despues de dejar worker")
            ocu = ocu -- [pid]
            disp = disp ++ [pid]
            {disp, ocu, pend}
          end

        {:fallo2, pid} ->
          # El worker ha caido -> Lo eliminamos de la lista y le proporcionamos otro
          ocu = ocu -- [pid]
          # Comprobamos que podemos proporcionarle otro worker
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

            IO.puts("Disponibles ->")
            IO.puts(inspect(disp))
            {disp, ocu, pend}
          else
            pend = pend ++ [pid]
            IO.puts("Estamos en el caso de no disponibles -> pend = ")
            IO.puts(inspect(pend))
            {disp, ocu, pend}
          end
      end

    pool(disp, ocu, pend)
  end
end
