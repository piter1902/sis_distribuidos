# AUTOR: Rafael Tolosana Calasanz
# FICHERO: repositorio.exs
# FECHA: 17 de octubre de 2019
# TIEMPO: 1 hora
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
    pid_servidor = spawn(LectEscrit, :server_variables, [procesos_espera, estado, myTime])
    # Thread encargado de escuchar las REQUEST de los demás procesos
    pid_thread = spawn(LectEscrit, :receive_petition, [procesos_espera, op_type, pid_servidor])
    procesos = procesar_lista(procesos, Node.self())
    conectarTodos(procesos, pid_thread)
    
    pid_procesos = reconocer_procesos(procesos)
    # IO.inspect(pid_procesos)
    
    begin_op(op_type, pid_procesos, pid_servidor,pid_thread)
    IO.puts("Estoy en SC #{Node.self()}")
    IO.inspect(Time.utc_now())

    send(
      pid_servidor,
      {:get, :tiempo, self()}
    )

    myTime =
      receive do
        {:ack, myTime} -> myTime
      end

    IO.puts(myTime)
    Process.sleep(3000)
    # No se pasa estado como parámetro ya que siempre se pone a "out" al llegar a end_op
    end_op(pid_thread, pid_servidor)
  end

  def reconocer_procesos(lista) do
    if lista != [] do
      pid_th = 
      receive do
        {:pid_thread, pid_thread} -> pid_thread
      end
      [_|resto] = lista
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

  def begin_op(op_type, procesos, pid_servidor,pid_thread) do
    # IO.puts("Inicio begin_op")

    send(
      pid_servidor,
      {:get, :estado, self()}
    )

    estado =
      receive do
        {:ack, estado} -> estado
      end

    estado = :trying

    send(
      pid_servidor,
      {:set, :estado, estado}
    )

    send(
      pid_servidor,
      {:get, :tiempo, self()}
    )

    myTime =
      receive do
        {:ack, myTime} -> myTime
      end

    # myTime = myTime + 1
    IO.puts("Tiempo recibido: #{myTime}")
    myTime = Time.add(myTime, 1)
    IO.puts("Tiempo cambiado: #{myTime}")

    send(
      pid_servidor,
      {:set, :tiempo, myTime}
    )

    # Hacemos REQUEST
    #send_petition(procesos, op_type, pid_servidor, pid_thread)
    Enum.map(procesos, fn x -> send_petition(x, op_type, pid_servidor, pid_thread) end )
    # Esperamos confirmación de todos procesos
    IO.inspect(procesos)
    #receive_permission(procesos)
    Enum.map(procesos, fn x -> receive_permission(x) end)
    estado = :in
    # Actualizamos valor a servidor de variables
    send(
      pid_servidor,
      {:set, :estado, estado}
    )

    # Se supone que estamos dentro
  end

  def end_op(pid_thread, pid_servidor) do
    estado = :out
    # Actualizamos valor de estado en servidor de variables
    send(
      pid_servidor,
      {:set, :estado, estado}
    )

    # Pedimos al thread que nos proporcione la lista de delayed
    send(
      pid_servidor,
      {:get, :procesos, self()}
    )
    
    receive do
      {:ack, procesos_espera} -> Enum.map(procesos_espera, fn x -> send_permission(x, pid_thread) end)
                                 IO.puts("Lista de procesos en espera: ")
                                 IO.inspect(procesos_espera)
    end

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
  end

  def send_petition(process, op_type, pid_servidor, pid_thread) do
    # Consultamos valor de myTime a servidor de variables

    send(
      pid_servidor,
      {:get, :tiempo, self()}
    )

    myTime =
      receive do
        {:ack, myTime} -> myTime
      end

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
      {:ok, pid} ->
        IO.puts("Nos ha llegado permiso de")
        IO.inspect(pid)
    end
  end

  # En esta función puedo recibir dos tipos de mensaje:
  # *Peticion de mi proceso padre de que necesita la lista de procesos_espera con lo que se la enviare
  # *Mensajes de REQUEST del resto de procesos.
  def receive_petition(procesos_espera, myOp, pid_servidor) do
    exclude = %{read: %{read: false, write: true}, write: %{read: true, write: true}}

    receive do
      {:request, other_time, pid, other_op} ->
        IO.puts("Me ha llegado un REQUEST")
        send(
          pid_servidor,
          {:get, :tiempo, self()}
        )

        myTime =
          receive do
            {:ack, myTime} -> myTime
          end

        myTime = Enum.max([myTime, other_time])
        # Actualizamos valor a servidor de variables
        send(
          pid_servidor,
          {:set, :tiempo, myTime}
        )

        # Pedimos valor del estado a servidor de variables
        send(
          pid_servidor,
          {:get, :estado, self()}
        )

        estado =
          receive do
            {:ack, estado} -> estado
          end
        
        IO.puts("Estado: #{estado}")
        IO.puts("Diferencia de tiempo: #{Time.compare(other_time, myTime)}")
        IO.puts("Exclusion: #{exclude[myOp][other_op]}")
        IO.puts("Mi op: #{myOp}, su op: #{other_op}")
        # Falta comprobar el estado(out,in)
        prio = estado != :out && Time.compare(other_time, myTime) == :gt && exclude[myOp][other_op]
        # En caso contrario, mandamos PERMISSION
        if prio do
          procesos_espera = procesos_espera ++ [pid]
          
          # Actualizamos valor a servidor de variables
          send(
            pid_servidor,
            {:set, :procesos, procesos_espera}
          )
        else
          send(
            pid,
            {:ok, self()}
          )
        end

        # Llamada recursiva
        receive_petition(procesos_espera, myOp, pid_servidor)

      {:fin_operacion} ->
        nil
        # Hemos recibido indicación de acabar
    end
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
end