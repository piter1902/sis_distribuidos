# AUTORES: Pedro Tamargo Allué y Juan José Tambo Tambo
# NIAs: 758267 y 755742
# FICHERO: escenario.exs
# FECHA: fecha de realizacion
# TIEMPO: tiempo en horas de codificación
# DESCRIPCION: breve descripcion del contenido del fichero

import Fib

defmodule Servidor do
  def server(dir_pool, proxy_machine) do
    Process.register(self(), :master)
    server_p(dir_pool, proxy_machine, 0)
  end

  defp server_p(dir_pool, proxy_machine, numPareja) do
    pid_pool = {:pool, dir_pool}
    # Escuchamos peticiones del cliente
    {pid_cli, num, nEnvio} =
      receive do
        {pid_cli, num, nEnvio} -> {pid_cli, num, nEnvio}
      end

    # IO.puts("Nos ha llegado una peticion de un cliente")
    # Creamos el proxy1 para comunicarnos con el worker
    proxy1 =
      Node.spawn(
        proxy_machine,
        Proxy,
        :proxy,
        [pid_cli, pid_pool, num, :vacio, numPareja, nEnvio]
      )

    # Creamos el proxy1 para comunicarnos con el worker
    proxy2 =
      Node.spawn(
        proxy_machine,
        Proxy,
        :proxy,
        [pid_cli, pid_pool, num, proxy1, numPareja, nEnvio]
      )

    # IO.puts("Peticiones enviadas a los proxys")
    server_p(dir_pool, proxy_machine, numPareja + 1)
  end
end

defmodule Proxy do
  # 300 ms de timeout
  @timeout 300
  # 3 reintentos permitidos por tarea
  @limite_tarea 3
  # Retardo por red
  @retardo
  def proxy(pid_client, pool, num, pid_proxy, numPareja, nEnvio) do
    IO.puts("INICIO Pareja #{numPareja}")
    # PRE-PROTOCOL
    pid_proxy = pre_protocol(pid_proxy)

    # Pide worker al pool
    send(
      pool,
      {:peti, self(), num}
    )

    # Esperamos a aceptar la peticion
    proxy_aceptar_peticion(pid_client, pool, num, 0, pid_proxy, numPareja, nEnvio)
  end

  # Funcion mediante la cual los proxys se conectan entre ellos
  def pre_protocol(pid_proxy) do
    # Caso de que tenemos ya el pid del otro proxy
    if pid_proxy != :vacio do
      send(
        pid_proxy,
        {:inicio, self()}
      )

      receive do
        {:ack} -> nil
      end

      pid_proxy
    else
      receive do
        {:inicio, pid_proxy} ->
          send(
            pid_proxy,
            {:ack}
          )

          pid_proxy
      end
    end
  end

  def proxy_aceptar_peticion(pid_client, pool, num, reintento, pid_proxy, numPareja, nEnvio) do
    # Recibimos el worker con el que trabajaremos
    pid_w =
      receive do
        {:ok, pid_w} -> pid_w
      end

    IO.puts("Soy Pareja #{numPareja} worker:#{inspect(pid_w)}")

    # Iniciamos la operacion del proxy
    proxy_operation(pid_client, pool, num, pid_w, reintento, pid_proxy, numPareja, nEnvio)
  end

  def proxy_operation(pid_client, pool, num, pid_w, reintento, pid_proxy, numPareja, nEnvio) do
    # Enviamos el mensaje al worker
    send(
      pid_w,
      {:req, {self(), num}}
    )

    # Esperamos al resultado -> con timeout
    t1 = Time.utc_now()

    result =
      receive do
        {:fin_proxy} ->
          IO.puts("EL OTRO PROXY HA TERMINADO. numPareja: #{numPareja} worker:#{inspect(pid_w)}")
          # No hemos terminado -> Le damos acceso
          send(
            pid_proxy,
            {:ok_fin}
          )

          # Comprobamos fallos
          comprobacion_fallo(
            pid_client,
            pool,
            num,
            pid_w,
            reintento,
            pid_proxy,
            :final,
            numPareja,
            nEnvio
          )

        result ->
          # Gestion de errores -> Comprobacion de que el resultado que obtenemos es valido (p.ej: es int y no float)
          # No hay errores -> Devolvemos el resultado al cliente y terminamos
          # Comprobamos el tiempo de respuesta de la operación
          tTotal = Time.diff(Time.utc_now(), t1, :microsecond)
          # Comprobamos si es entero. En caso negativo, lo convertimos a entero.
          result =
            unless is_integer(result) do
              trunc(result)
            else
              result
            end

          IO.puts(
            "Tiempo total de resolucion Pareja: #{numPareja} worker:#{inspect(pid_w)}: #{
              inspect(tTotal)
            }"
          )

          info =
            cond do
              num <= 36 ->
                cond do
                  tTotal <= 80 * 1000 -> :fib_of
                  tTotal <= 90 * 1000 -> :fib_tr
                  true -> :fib_fib
                end

              num <= 100 ->
                if tTotal <= 80 * 1000 do
                  :fib_of
                else
                  :fib_tr
                end

              num == 1500 ->
                :fib_tr
            end

          end_proxy(result, pid_client, pool, pid_w, pid_proxy, info, numPareja, nEnvio)
      after
        @timeout ->
          comprobacion_fallo(
            pid_client,
            pool,
            num,
            pid_w,
            reintento,
            pid_proxy,
            :rutina,
            numPareja,
            nEnvio
          )
      end
  end

  def comprobacion_fallo(
        pid_client,
        pool,
        num,
        pid_w,
        reintento,
        pid_proxy,
        tipo,
        numPareja,
        nEnvio
      ) do
    {_, dir_w} = pid_w

    IO.puts(
      "Iniciamos comprobacion de fallo de tipo #{inspect(tipo)}. Pareja #{numPareja}. Worker #{
        inspect(pid_w)
      }"
    )

    if Node.ping(dir_w) == :pong do
      IO.puts("El nodo da ping. Pareja #{numPareja}. Worker #{inspect(pid_w)}")
      # El nodo pid_w esta vivo -> reintentar tarea N veces
      # Tipo = final, así que terminamos ejecución
      if tipo == :rutina do
        # Caso de mucho tiempo ejecución o ha lanzado excepción
        if reintento == @limite_tarea do
          IO.puts(
            "REINTENTO MAXIMO. Pareja #{numPareja}. Worker #{inspect(pid_w)}. COMUNICO CAIDA Y PIDO OTRO WORKER."
          )

          # Hemos llegado al limite -> El nodo esta congestionado => Pedimos otro a pool y reintentamos
          # Le devolvemos el worker a pool
          send(
            pool,
            # s Hemos considerado que llegado a este punto, el nodo no va a contestar.
            {:fallo2, pid_w}
          )

          send(
            pool,
            {:peti, self(), num}
          )

          # # Pedimos otro y reintentamos (reintento = 0)
          # send(
          #   pool,
          #   {:peti, self(), num}
          # )

          proxy_aceptar_peticion(pid_client, pool, num, 0, pid_proxy, numPareja, nEnvio)
        else
          proxy_operation(
            pid_client,
            pool,
            num,
            pid_w,
            reintento + 1,
            pid_proxy,
            numPareja,
            nEnvio
          )
        end
      else
        # En este caso, el otro proxy ha terminado, comprobamos estado de nuestro Worker.
        # En el caso de que nuestro worker haya fallado, el siguiente proxy comprobará su estado
        info =
          cond do
            num <= 36 ->
              :fib_fib

            num <= 100 ->
              :fib_of

            true ->
              :fib_tr
          end

        # Le devolvemos el worker a pool
        send(
          pool,
          {:ok, pid_w, info}
        )
      end
    else
      IO.puts("El nodo no da ping. Pareja #{numPareja}. Worker #{inspect(pid_w)}. COMUNICO CAIDA")
      # El nodo ha caido (no ha devuelto :pong) -> :pang
      # Comunicamos al pool la caida y reintentamos la tarea
      send(
        pool,
        {:fallo2, pid_w, self(), num}
      )

      if tipo == :rutina do
        send(
          pool,
          {:peti, self(), num}
        )

        # Volvemos a esperar el envio del worker
        proxy_aceptar_peticion(pid_client, pool, num, 0, pid_proxy, numPareja, nEnvio)
      end

      # En caso tipo == final, finalizaría ejecución
    end
  end

  def end_proxy(result, pid_client, pool, pid_w, pid_proxy, info, numPareja, nEnvio) do
    # POST PROTOCOL: indicamos al otro proxy acerca de nuestra finalización
    send(
      pid_proxy,
      {:fin_proxy}
    )

    # Esperamos a recibir permiso
    receive do
      {:ok_fin} ->
        IO.puts("SOY PROXY DE LA PAREJA #{numPareja} Y HE TERMINADO ANTES")
        # Este es el caso de que uno termina antes que otro
        IO.puts("ENVIO EL RESULTADO y tengo a #{inspect(pid_w)}. Pareja #{numPareja}")

        send(
          pid_client,
          {:result, result, nEnvio}
        )

      {:fin_proxy} ->
        # Este es el caso de que ambos han terminado casi a la vez
        if self() > pid_proxy do
          # Tenemos prioridad, ya que nuestro pid es mayor
          IO.puts("SOY PROXY DE LA PAREJA #{numPareja} Y TENGO PRIORIDAD")
          # Devolvemos el resultado al cliente
          # send(
          #   pid_client,
          #   {:fin, result, time, nEnvio}
          # )
          IO.puts("ENVIO EL RESULTADO y tengo a #{inspect(pid_w)}. Pareja #{numPareja}")

          send(
            pid_client,
            {:result, result, nEnvio}
          )
        end
    end

    # No tiene prioridad, pero sabemos que el nodo ha funcionado bien, porque tenemos resultado
    # Devolvemos el worker al pool
    send(
      pool,
      {:ok, pid_w, info}
    )
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
    lista_fib = []
    lista_of = []

    # Al inicio, lista_workers = lista_tr ya que en la primera tarea todos se comportan como un nodo normal (fibonacci_tr)
    pool(lista_workers, lista_fib, lista_of, lista_ocupados, lista_pendientes)
  end

  # Mensajes que nos pueden llegar ->
  #   :peti   -> peticion de worker
  #   :ok     -> peticion de fin de uso de worker (sin problemas)
  #   :fallo2 -> fallo de tipo2 ==> El nodo ha caido
  #   :fallo1 -> fallo de tipo1 ==> El nodo responde mal
  defp pool(disp_tr, disp_fib, disp_of, ocu, pend) do
    # Esperamos una peticion del proxy
    {disp_tr, disp_fib, disp_of, ocu, pend} =
      receive do
        # Peti1 se corresponde a una petición de un número entre 1 y 36
        {:peti, pid, num} ->
          IO.puts("Ha llegado peticion")
          # Nos llega peticion y llamamos a función para saber qué worker devolverle.
          # {disp_tr, disp_fib, disp_of, ocu, pend} = dar_worker(disp_tr, disp_fib, disp_of, ocu, pend, pid, num)
          # {disp_tr, disp_fib, disp_of, ocu, pend}
          dar_worker(disp_tr, disp_fib, disp_of, ocu, pend, pid, num)

        {:ok, pid, info} ->
          IO.puts("Nos ha llegado fin del worker #{inspect(pid)}")
          # Fin de worker -> anadimos a disponible
          # Comprobamos si hay alguien esperando
          ocu = ocu -- [pid]

          {disp_tr, disp_fib, disp_of} =
            cond do
              info == :fib_tr ->
                disp_tr = disp_tr ++ [pid]
                {disp_tr, disp_fib, disp_of}

              info == :fib_fib ->
                disp_fib = disp_fib ++ [pid]
                {disp_tr, disp_fib, disp_of}

              info == :fib_of ->
                disp_of = disp_of ++ [pid]
                {disp_tr, disp_fib, disp_of}

              true ->
                {disp_tr, disp_fib, disp_of}
            end

          IO.puts("Worker #{inspect(pid)} con info #{inspect(info)}")
          IO.puts("Lista de pendientes = #{inspect(pend)}")

          if pend != [] do
            [{pid_proxy, num} | resto] = pend
            pend = resto
            IO.puts("Hay pendientes, le enviamos worker")

            # {disp_tr, disp_fib, disp_of, ocu, pend} = dar_worker(disp_tr, disp_fib, disp_of, ocu, pend, pid_proxy, num)
            # {disp_tr, disp_fib, disp_of, ocu, pend}
            dar_worker(disp_tr, disp_fib, disp_of, ocu, pend, pid_proxy, num)
          else
            {disp_tr, disp_fib, disp_of, ocu, pend}
          end

        {:fallo2, pid_w, pid_proxy, num} ->
          IO.inspect("Ha caido un worker.")
          # El worker ha caido -> Lo eliminamos de la lista y le proporcionamos otro
          ocu = ocu -- [pid_w]
          {disp_tr, disp_fib, disp_of, ocu, pend}
      end

    # IO.puts("Lista tr = #{inspect(disp_tr)}")
    # IO.puts("Lista fib = #{inspect(disp_fib)}")
    # IO.puts("Lista of = #{inspect(disp_of)}")
    pool(disp_tr, disp_fib, disp_of, ocu, pend)
  end

  defp dar_worker(disp_tr, disp_fib, disp_of, ocu, pend, pid, num) do
    cond do
      num <= 36 ->
        cond do
          disp_fib != [] ->
            [head | tail] = disp_fib
            disp_fib = tail
            # Marcamos al worker que enviamos como ocupado
            ocu = ocu ++ [head]
            # Enviamos un worker al proxy
            send(
              pid,
              {:ok, head}
            )

            {disp_tr, disp_fib, disp_of, ocu, pend}

          disp_of != [] ->
            [head | tail] = disp_of
            disp_of = tail
            # Marcamos al worker que enviamos como ocupado
            ocu = ocu ++ [head]
            # Enviamos un worker al proxy
            send(
              pid,
              {:ok, head}
            )

            {disp_tr, disp_fib, disp_of, ocu, pend}

          disp_tr != [] ->
            [head | tail] = disp_tr
            disp_tr = tail
            # Marcamos al worker que enviamos como ocupado
            ocu = ocu ++ [head]
            # Enviamos un worker al proxy
            send(
              pid,
              {:ok, head}
            )

            {disp_tr, disp_fib, disp_of, ocu, pend}

          # No hay ninguna lista disponible
          true ->
            pend = pend ++ [{pid, num}]
            # IO.puts("Estamos en el caso de no disponibles -> pend = ")
            # IO.puts(inspect(pend))
            {disp_tr, disp_fib, disp_of, ocu, pend}
        end

      num <= 100 ->
        cond do
          disp_of != [] ->
            [head | tail] = disp_of
            disp_of = tail
            # Marcamos al worker que enviamos como ocupado
            ocu = ocu ++ [head]
            # Enviamos un worker al proxy
            send(
              pid,
              {:ok, head}
            )

            {disp_tr, disp_fib, disp_of, ocu, pend}

          disp_tr != [] ->
            [head | tail] = disp_tr
            disp_tr = tail
            # Marcamos al worker que enviamos como ocupado
            ocu = ocu ++ [head]
            # Enviamos un worker al proxy
            send(
              pid,
              {:ok, head}
            )

            {disp_tr, disp_fib, disp_of, ocu, pend}

          # No hay ninguna lista disponible
          true ->
            pend = pend ++ [{pid, num}]
            IO.puts("Estamos en el caso de no disponibles -> pend = ")
            # IO.puts(inspect(pend))
            {disp_tr, disp_fib, disp_of, ocu, pend}
        end

      # Caso de 1500
      true ->
        if disp_tr != [] do
          [head | tail] = disp_tr
          disp_tr = tail
          # Marcamos al worker que enviamos como ocupado
          ocu = ocu ++ [head]
          # Enviamos un worker al proxy
          send(
            pid,
            {:ok, head}
          )

          {disp_tr, disp_fib, disp_of, ocu, pend}
        else
          pend = pend ++ [{pid, num}]
          IO.puts("Estamos en el caso de no disponibles -> pend = #{inspect(pend)}")
          # IO.puts(inspect(pend))
          {disp_tr, disp_fib, disp_of, ocu, pend}
        end
    end
  end
end
