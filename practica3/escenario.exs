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
    server_p(dir_pool, proxy_machine)
  end

  defp server_p(dir_pool, proxy_machine) do
    pid_pool = {:pool, dir_pool}
    # Escuchamos peticiones del cliente
    IO.puts("Pool: #{dir_pool}")

    {pid_cli, num} =
      receive do
        {pid_cli, num} -> {pid_cli, num}
      end

    IO.puts("Nos ha llegado una peticion de un cliente")
    # Creamos el proxy1 para comunicarnos con el worker
    proxy1 =
      Node.spawn(
        proxy_machine,
        Proxy,
        :proxy,
        [pid_cli, pid_pool, num, :vacio]
      )

    # Creamos el proxy1 para comunicarnos con el worker
    proxy2 =
      Node.spawn(
        proxy_machine,
        Proxy,
        :proxy,
        [pid_cli, pid_pool, num, proxy1]
      )

    IO.puts("Peticiones enviadas a los proxys")
    server_p(dir_pool, proxy_machine)
  end
end

defmodule Proxy do
  # 300 ms de timeout
  @timeout 300
  # 3 reintentos permitidos por tarea
  @limite_tarea 3
  def proxy(pid_client, pool, num, pid_proxy) do
    IO.puts("Soy proxy y acabo de empezar")
    # PRE-PROTOCOL
    pid_proxy = pre_protocol(pid_proxy)

    # Pide worker al pool
    send(
      pool,
      {:peti, self(), num}
    )

    # Esperamos a aceptar la peticion
    proxy_aceptar_peticion(pid_client, pool, num, 0, pid_proxy)
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

  def proxy_aceptar_peticion(pid_client, pool, num, reintento, pid_proxy) do
    # Recibimos el worker con el que trabajaremos
    pid_w =
      receive do
        {:ok, pid_w} -> pid_w
      end

    # Iniciamos la operacion del proxy
    proxy_operation(pid_client, pool, num, pid_w, reintento, pid_proxy)
  end

  def proxy_operation(pid_client, pool, num, pid_w, reintento, pid_proxy) do
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
          comprobacion_fallo(
            pid_client,
            pool,
            num,
            pid_w,
            reintento,
            pid_proxy,
            :final
          )

        result ->
          # Gestion de errores -> Comprobacion de que el resultado que obtenemos es valido (p.ej: es int y no float)
          # No hay errores -> Devolvemos el resultado al cliente y terminamos
          # Comprobamos el tiempo de respuesta de la operación
          tTotal = Time.diff(Time.utc_now(), t1, :microsecond)

          info =
            cond do
              tTotal <= 650_000 && num <= 36 ->
                :fib_fib

              tTotal <= 100 && num <= 100 ->
                :fib_of

              tTotal <= 250 && num == 1500 ->
                :fib_tr

              # Suponemos caso poco probable, pero se lo enviamos a fibonacci
              true ->
                :fib_fib
            end

          end_proxy(result, pid_client, pool, pid_w, pid_proxy, info)
      after
        @timeout ->
          comprobacion_fallo(
            pid_client,
            pool,
            num,
            pid_w,
            reintento,
            pid_proxy,
            :rutina
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
        tipo
      ) do
    if Node.ping(pid_w) == :pong do
      # El nodo pid_w esta vivo -> reintentar tarea N veces
      # Tipo = final, así que terminamos ejecución
      if tipo == :rutina do
        # Caso de mucho tiempo ejecución o ha lanzado excepción
        if reintento == @limite_tarea do
          # Hemos llegado al limite -> El nodo esta congestionado => Pedimos otro a pool y reintentamos
          # Le devolvemos el worker a pool
          send(
            pool,
            # s Hemos considerado que llegado a este punto, el nodo no va a contestar.
            {:fallo2, pid_w}
          )

          # # Pedimos otro y reintentamos (reintento = 0)
          # send(
          #   pool,
          #   {:peti, self(), num}
          # )

          proxy_aceptar_peticion(pid_client, pool, num, 0, pid_proxy)
        else
          proxy_operation(
            pid_client,
            pool,
            num,
            pid_w,
            reintento + 1,
            pid_proxy
          )
        end
      else
        # Le devolvemos el worker a pool
        send(
          pool,
          {:ok, pid_w}
        )
      end
    else
      # El nodo ha caido (no ha devuelto :pong) -> :pang
      # Comunicamos al pool la caida y reintentamos la tarea
      send(
        pool,
        {:fallo2, pid_w, self(), num}
      )

      if tipo == :rutina do
        # Volvemos a esperar el envio del worker
        proxy_aceptar_peticion(pid_client, pool, num, 0, pid_proxy)
      end

      # En caso tipo == final, finalizaría ejecución
    end
  end

  def end_proxy(result, pid_client, pool, pid_w, pid_proxy, info) do
    # POST PROTOCOL: indicamos al otro proxy acerca de nuestra finalización
    send(
      pid_proxy,
      {:fin_proxy}
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
          # Nos llega peticion y llamamos a función para saber qué worker devolverle.
          dar_worker(disp_tr, disp_fib, disp_of, ocu, pend, pid, num)

        {:ok, pid, info} ->
          IO.puts("Nos ha llegado peticion de fin del worker #{pid}")
          # Fin de worker -> anadimos a disponible
          # Comprobamos si hay alguien esperando   
          ocu = ocu -- [pid]

          {disp_tr, disp_fib, disp_of} =
            cond do
              info == :fib_tr ->
                disp_tr ++ [pid]
                {disp_tr, disp_fib, disp_of}

              info == :fib_fib ->
                disp_fib ++ [pid]
                {disp_tr, disp_fib, disp_of}

              info == :fib_of ->
                disp_of ++ [pid]
                {disp_tr, disp_fib, disp_of}

              true ->
                {disp_tr, disp_fib, disp_of}
            end

          if pend != [] do
            [{pid_proxy, num} | resto] = pend
            pend = resto
            dar_worker(disp_tr, disp_fib, disp_of, ocu, pend, pid_proxy, num)
          else
            {disp_tr, disp_fib, disp_of, ocu, pend}
          end

        {:fallo2, pid_w, pid_proxy, num} ->
          # El worker ha caido -> Lo eliminamos de la lista y le proporcionamos otro
          ocu = ocu -- [pid_w]
          # Comprobamos que podemos proporcionarle otro worker
          dar_worker(disp_tr, disp_fib, disp_of, ocu, pend, pid_proxy, num)
      end

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
            IO.puts("Estamos en el caso de no disponibles -> pend = ")
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
          IO.puts("Estamos en el caso de no disponibles -> pend = ")
          # IO.puts(inspect(pend))
          {disp_tr, disp_fib, disp_of, ocu, pend}
        end
    end
  end
end
