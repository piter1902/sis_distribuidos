# AUTOR: Pedro Tamargo -  Juan José Tambo 
# NIAs: 
# FICHERO: repositorio.exs
# FECHA: 11 de noviembre de 2019
# TIEMPO: 3 horas
# DESCRIPCI'ON:  	Implementa un repositorio para gestionar el enunciado de un trabajo de asignatura.
# 				El enunciado tiene tres partes: resumen, parte principal y descripci'on de la entrega.
# 				El repositorio consta de un servidor que proporciona acceso individual a cada parte del enunciado,
# 				bien en lectura o bien en escritura				

defmodule Repositorio do
  def init do
    repo_server({"", "", ""})
  end

  def repo_server({resumen, principal, entrega}) do
    {n_resumen, n_principal, n_entrega} =
      receive do
        {:update_resumen, c_pid, descripcion} ->
          send(c_pid, {:reply, :ok})
          {descripcion, principal, entrega}

        {:update_principal, c_pid, descripcion} ->
          send(c_pid, {:reply, :ok})
          {resumen, descripcion, entrega}

        {:update_entrega, c_pid, descripcion} ->
          send(c_pid, {:reply, :ok})
          {resumen, principal, descripcion}

        {:read_resumen, c_pid} ->
          send(c_pid, {:reply, resumen})
          {resumen, principal, entrega}

        {:read_principal, c_pid} ->
          send(c_pid, {:reply, principal})
          {resumen, principal, entrega}

        {:read_entrega, c_pid} ->
          send(c_pid, {:reply, entrega})
          {resumen, principal, entrega}
      end

    repo_server({n_resumen, n_principal, n_entrega})
  end
end

defmodule LectEscrit do
  # Type indica si lector o escritor
  def init(op_type, procesos) do
    Process.sleep(2000)
    # La uso para el perm_delayed
    procesos_espera = []
    # Cogemos marca temporal de la peticion
    myTime = Time.utc_now()
    estado = :out
    # Thread encargado de la gestion de las variables compartidas (servidor de variables)
    pid_servidor = spawn(LectEscrit, :server_variables, [procesos_espera, estado, myTime])

    # Thread encargado de mutex
    pid_mutex = spawn(Mutex, :init, [])

    # Thread encargado de escuchar las REQUEST de los demás procesos
    pid_thread =
      spawn(LectEscrit, :receive_petition, [procesos_espera, op_type, pid_servidor, pid_mutex])

    # Conectamos a todos los procesos de la lista <procesos>
    procesos = procesar_lista(procesos, Node.self())
    # IO.puts("Procesos conectados")
    # IO.inspect(procesos)
    conectarTodos(procesos, pid_thread)
    IO.puts("Aqui llego")
    # <pid_procesos> contiene los pid de los procesos REQUEST de los otros nodos
    pid_procesos = reconocer_procesos(procesos)
    
    #Parámetros que devuelve la función init
    {pid_procesos, pid_servidor, pid_thread, pid_mutex}

    # Desacoplamos el codigo de la seccion critica de lo que es el init del sistema
    # begin_op(op_type, pid_procesos, pid_servidor, pid_thread, pid_mutex)
    # IO.puts("Estoy en SC #{Node.self()}")
    # IO.inspect(Time.utc_now())

    # myTime = get(pid_servidor, :tiempo)

    # IO.puts(myTime)
    # Process.sleep(3000)
    # end_op(pid_thread, pid_servidor)
  end

  def reconocer_procesos(lista) do
    if lista != [] do
      pid_th =
        receive do
          {:pid_thread, pid_thread} -> pid_thread
                                      #  IO.puts("Recibido permiso de ")
                                      #  IO.inspect(pid_thread)
        end
      [_ | resto] = lista
      lista = resto
      [pid_th] ++ reconocer_procesos(lista)
    else
      []
    end
  end

  def procesar_lista(procesos, comparar) do
    if procesos != [] do
      [{at, nodo} | resto] = procesos
      procesos = resto

      if nodo != comparar do
        # Lo añadimos a la lista
        [{at, nodo}] ++ procesar_lista(resto, comparar)
      else
        procesar_lista(resto, comparar)
      end
    else
      []
    end
  end

  def conectarTodos(procesos, _) when procesos == [] do
    # IO.puts("Conectado a todos")
    # IO.puts(inspect(Node.list()))
  end

  def conectarTodos(procesos, pid_thread) when procesos != [] do
    [{at, node} | resto] = procesos
    procesos = resto
    Node.connect(node)
    send(
      {at, node},
      {:pid_thread, pid_thread}
    )

    # IO.puts("Hola #{node}")
    conectarTodos(procesos, pid_thread)
  end

  def begin_op(op_type,procesos, pid_servidor, pid_thread, pid_mutex) do
    
    # Para garantizar la exclusión mútua, se realiza wait al mútex
    wait(pid_mutex)

    estado = get(pid_servidor, :estado)
    estado = :trying
    set(pid_servidor, :estado, estado)

    myTime = get(pid_servidor, :tiempo)

    # myTime = myTime + 1
    IO.puts("Tiempo recibido: #{myTime}")
    myTime = Time.add(myTime, 1)
    IO.puts("Tiempo cambiado: #{myTime}")

    set(pid_servidor, :tiempo, myTime)

    # Fin de exclusión mútua
    signal(pid_mutex)
    # Hacemos REQUEST
    # send_petition(procesos, op_type, pid_servidor, pid_thread)
    Enum.map(procesos, fn x -> send_petition(x, op_type, pid_servidor, pid_thread) end)
    
    # Esperamos confirmación de todos procesos
    Enum.map(procesos, fn x -> receive_permission(x) end)
    wait(pid_mutex)
    estado = :in
    # Actualizamos valor a servidor de variables
    set(pid_servidor, :estado, estado)

    signal(pid_mutex)

    # Se supone que estamos dentro
  end

  def end_op(pid_thread, pid_servidor) do
    estado = :out
    # Actualizamos valor de estado en servidor de variables
    set(pid_servidor, :estado, estado)

    # Pedimos al thread que nos proporcione la lista de delayed
    procesos_espera = get(pid_servidor, :procesos)
    # Enviamos permiso a todos los procesos encolados
    Enum.map(procesos_espera, fn x -> send_permission(x, pid_thread) end)

  end

  def send_petition(process, op_type, pid_servidor, pid_thread) do
    # Consultamos valor de myTime a servidor de variables
    myTime = get(pid_servidor, :tiempo)

    # Enviamos request a cada uno de los procesos
    send(
      process,
      {:request, myTime, self(), op_type}
    )
  end

  def send_permission(process, pid_thread) do
    # Enviamos el permiso para entrar en SC
    send(
      process,
      {:ok, pid_thread}
    )
  end

  def receive_permission(x) do
    receive do
      # Recibimos confirmacion de todos procesos y eliminamos de la lista
      {:ok, pid} -> nil
    end
  end

  # En esta función puedo recibir dos tipos de mensaje:
  # *Peticion de mi proceso padre de que necesita la lista de procesos_espera con lo que se la enviare
  # *Mensajes de REQUEST del resto de procesos.
  def receive_petition(procesos_espera, myOp, pid_servidor, pid_mutex) do
    exclude = %{read: %{read: false, write: true}, write: %{read: true, write: true}}

    receive do
      {:request, other_time, pid, other_op} ->
        IO.puts("Me ha llegado un REQUEST")
        wait(pid_mutex)

        # Obtenemos el tiempo del servidor
        myTime = get(pid_servidor, :tiempo)

        # mt -> variable temporal
        mt = myTime
        # Calculamos el maximo de los relojes logicos
        myTime = Enum.max([myTime, other_time])
        # Actualizamos valor a servidor de variables
        send(
          pid_servidor,
          {:set, :tiempo, myTime}
        )

        # Pedimos valor del estado a servidor de variables
        estado = get(pid_servidor, :estado)

        IO.puts("Estado: #{estado}")
        IO.puts("myTime #{inspect(mt)} | other_time #{inspect(other_time)}")
        IO.puts("Diferencia de tiempo: #{Time.compare(other_time, myTime)}")
        IO.puts("Mi op: #{myOp}, su op: #{other_op}")
        IO.puts("Exclusion: #{exclude[myOp][other_op]}")
        # Falta comprobar el estado(out,in)
        prio = estado != :out && Time.diff(other_time, mt, :millisecond) > 0 && exclude[myOp][other_op]
        IO.puts("La prioridad es: #{prio}")
        signal(pid_mutex)

        procesos_espera=
        if prio do
          procesos_espera = procesos_espera ++ [pid]
          # Actualizamos valor a servidor de variables
          set(pid_servidor, :procesos, procesos_espera)
          procesos_espera
        else
          send(
            pid,
            {:ok, self()}
          )
          procesos_espera
        end

        # Llamada recursiva
        receive_petition(procesos_espera, myOp, pid_servidor, pid_mutex)

      {:fin_operacion} -> IO.puts("Muere receive_petition")
        # Hemos recibido indicación de acabar
    end
  end

  # Funcion que devuelve la variable asociada al atomo <variable> en el servidor de variables
  def get(pid_servidor, variable) do
    # Pedimos valor del estado a servidor de variables
    send(
      pid_servidor,
      {:get, variable, self()}
    )

    var =
      receive do
        {:ack, var} -> var
      end

    var
  end

  # Funcion que asocia el nuevo valor <valor> al atomo <variable> en el servidor de variables
  def set(pid_servidor, variable, valor) do
    send(
      pid_servidor,
      {:set, variable, valor}
    )
  end

  # Función encargada de enviar a proceso de variables, proceso de recepción de peticiones
  # y proceso mutex la incicación de terminar ejecución.
  def end_process(pid_thread, pid_servidor, pid_mutex) do
    # Hacemos que thread "receive_petition" acabe
    send(
      pid_thread,
      {:fin_operacion}
    )

    # Hacemos que servidor de variables acabe
    send(
      pid_servidor,
      {:fin_operacion}
    )

    #Hacemos que proceso muex termine
    send(
      pid_mutex,
      {:fin_operacion}
    )
  end
  def server_variables(procesos_espera, estado, myTime) do
    receive do
      {:get, var, pid} ->
        {procesos_espera, estado, myTime} =
          case var do
            :procesos ->
              send(
                pid,
                {:ack, procesos_espera}
              )

              {procesos_espera, estado, myTime}

            :estado ->
              send(
                pid,
                {:ack, estado}
              )

              {procesos_espera, estado, myTime}

            :tiempo ->
              send(
                pid,
                {:ack, myTime}
              )

              {procesos_espera, estado, myTime}
          end

        server_variables(procesos_espera, estado, myTime)

      {:set, var, nuevo_valor} ->
        {procesos_espera, estado, myTime} =
          case var do
            :procesos ->
              procesos_espera = nuevo_valor
              {procesos_espera, estado, myTime}

            :estado ->
              estado = nuevo_valor
              {procesos_espera, estado, myTime}

            :tiempo ->
              myTime = nuevo_valor
              {procesos_espera, estado, myTime}
          end

        server_variables(procesos_espera, estado, myTime)

      {:fin_operacion} ->
        nil
    end
  end

  def signal(pid_mutex) do
    send(
      pid_mutex,
      {:signal}
    )
  end

  def wait(pid_mutex) do
    send(
      pid_mutex,
      {:wait, self()}
    )

    receive do
      {:wait_ack} -> nil
    end
  end
end

defmodule Mutex do
  def init() do
    mutex(1, [])
  end

  defp mutex(valor, lista_espera) do
    {valor, lista_espera} =
      receive do
        {:signal} ->
          if lista_espera != [] do
            [proceso | cola] = lista_espera
            lista_espera = cola

            send(
              proceso,
              {:wait_ack}
            )

            {valor, lista_espera}
          else
            {valor + 1, lista_espera}
          end
          mutex(valor, lista_espera)
        {:wait, proceso} ->
          if valor != 0 do
            send(
              proceso,
              {:wait_ack}
            )

            {valor - 1, lista_espera}
          else
            {valor, lista_espera ++ [proceso]}
          end
          mutex(valor, lista_espera)
        {:fin_operacion} -> nil
      end
  end
end