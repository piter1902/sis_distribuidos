Code.require_file("#{__DIR__}/cliente_gv.exs")

defmodule ServidorSA do
  # estado del servidor
  # Si rol: :primario, para poder contestar peticiones, copia debe ser != :undefined, en caso contrario,
  #         se para el sistema por fallo de disponibilidad.
  #     rol = {:espera, :primario, :copia}
  defstruct rol: :undefined,
            num_vista: 0,
            pid_primario: :undefined,
            pid_copia: :undefined,
            datos: %{}

  @intervalo_latido 50
  @tiempo_espera_de_respuesta 30
  @doc """
      Obtener el hash de un string Elixir
          - Necesario pasar, previamente,  a formato string Erlang
       - Devuelve entero
  """
  def hash(string_concatenado) do
    String.to_charlist(string_concatenado) |> :erlang.phash2()
  end

  @doc """
      Poner en marcha el servidor para gestión de vistas
      Devolver atomo que referencia al nuevo nodo Elixir
  """
  @spec startNodo(String.t(), String.t()) :: node
  def startNodo(nombre, maquina) do
    # fichero en curso
    NodoRemoto.start(nombre, maquina, __ENV__.file)
  end

  @doc """
      Poner en marcha servicio trás esperar al pleno funcionamiento del nodo
  """
  @spec startService(node, node) :: pid
  def startService(nodoSA, nodo_servidor_gv) do
    NodoRemoto.esperaNodoOperativo(nodoSA, __MODULE__)

    # Poner en marcha el código del gestor de vistas
    Node.spawn(nodoSA, __MODULE__, :init_sa, [nodo_servidor_gv])
  end

  # ------------------- Funciones privadas -----------------------------

  def monitor_latidos(pid_principal) do
    send(pid_principal, {:envia_latido})
    Process.sleep(@intervalo_latido)
    monitor_latidos(pid_principal)
  end

  def init_sa(nodo_servidor_gv) do
    Process.register(self(), :servidor_sa)
    # Process.register(self(), :cliente_gv)

    # ------------- VUESTRO CODIGO DE INICIALIZACION AQUI..........
    # otro proceso concurrente
    spawn(__MODULE__, :monitor_latidos, [self()])

    # Poner estado inicial
    bucle_recepcion_principal(nodo_servidor_gv, %ServidorSA{})
  end

  defp bucle_recepcion_principal(nodo_servidor_gv, estado) do
    {nodo_servidor_gv, estado} =
      receive do
        # Solicitudes de lectura y escritura
        # de clientes del servicio alm.
        {op, param, nodo_origen} ->
          estado =
            cond do
              estado.rol == :primario ->
                # Solo podemos contestar si tenemos copia
                estado =
                  if estado.pid_copia != :undefined do
                    # Repetimos la operacion al nodo copia con nodo_origen = self()
                    send(
                      estado.pid_copia,
                      {op, param, self()}
                    )

                    # Realizamos la tarea -> Fx auxiliar ?
                    {estado, valor} = realizar_tarea(op, param, estado)

                    # Recibimos la confirmacion de la copia
                    receive do
                      {:copia_ok, _} -> nil
                    after
                      1000 ->
                        # Ha saltado el timeout
                        nil
                    end

                    # Y si ocurre un error aqui??

                    # Enviamos la confirmacion al cliente
                    send(
                      nodo_origen,
                      {:resultado, valor}
                    )

                    # Devolvemos el estado modificado
                    estado
                  else
                    # No tenemos una copia. Informamos de que no hemos validado la vista
                    send(
                      nodo_origen,
                      {:resultado, :no_soy_primario_valido}
                    )

                    # Devolvemos el estado modificado
                    estado
                  end

                estado

              estado.rol == :copia ->
                # Ralizamos la tarea -> Fx auxiliar
                {estado, valor} = realizar_tarea(op, param, estado)

                send(
                  nodo_origen,
                  {:copia_ok, valor}
                )

                estado

              true ->
                # No somos ni primario ni copia. Ha debido ser un error
                send(
                  nodo_origen,
                  {:resultado, :no_soy_primario_valido}
                )
            end

          {nodo_servidor_gv, estado}

        # ----------------- vuestro código

        # Distintas operaciones que solo se ejecutaran si nuestro estado.rol == :copia

        # Mensaje del thread para enviar latido
        {:envia_latido} ->
          # Enviamos -1 si no tenemos una copia asignada -> No validamos la vista
          n_vista =
            cond do
              estado.pid_primario == Node.self() and estado.pid_copia != :undefined ->
                # Somos el primario y tenemos copia
                estado.num_vista

              estado.pid_primario == Node.self() and estado.pid_copia == :undefined ->
                # Somos el primario y no tenemos copia -> Fallo de disponibilidad. No validamos la vista
                -1

              estado.pid_primario != Node.self() ->
                # No somos primario, enviamos el numero de vista que teniamos asociado
                estado.num_vista
            end

          # Enviamos el latido al gestor
        #   IO.puts("nodo_servidor_gv: #{inspect(nodo_servidor_gv)}")
        #   IO.puts("Num vista = #{n_vista}")
        #   IO.puts("Mi PID: #{inspect(Node.self())}")

          send({:servidor_gv, nodo_servidor_gv}, {:latido, n_vista, Node.self()})

          # esperar respuesta del servidor_gv
          {vista_gv, is_ok} =
            receive do
              {:vista_tentativa, vista, encontrado?} -> {vista, encontrado?}
              _otro -> exit(" ERROR: en funcion #latido# de modulo ClienteGV")
            after
              @tiempo_espera_de_respuesta -> {ServidorGV.vista_inicial(), false}
            end
        IO.puts("La copia que nos ha devuelto de tentativa es: #{inspect(vista_gv.copia)}")
          # Actualizamos el estado en base a la vista tentativa
          estado =
            cond do
              is_ok == false and vista_gv.primario == Node.self() ->
                IO.puts("Soy primario y vista no validada")
                # Somos primario pero la vista no está validada. (Nos acaban de promocionar)
                # Actualizamos el valor de nuestra copia a la copia actual en el gestor de vistas
                estado = %ServidorSA{estado | pid_copia: vista_gv.copia}

                # Cuidado con esta parte.
                # estado =
                #   if vista_gv.copia != :undefined do
                #     # Podemos confirmar la vista al tener un nodo copia -> No hay fallo de disponibilidad
                #     estado.num_vista = vista_gv.num_vista
                #     estado
                #   else
                #     # No podemos confirmar la vista.
                #     estado.num_vista = -1
                #     estado
                #   end

                # Asumimos que el numero de vista es correcto, y a la hora de enviar el latido confirmando la vista, evaluaremos la vista.
                estado = %ServidorSA{estado | num_vista: vista_gv.num_vista}
                estado = %ServidorSA{estado | pid_primario: Node.self()}
                estado = %ServidorSA{estado | pid_copia: vista_gv.copia}
                estado = %ServidorSA{estado | rol: :primario}
                # Transferencia de los datos a la nueva copia -> Fx auxiliar
                if estado.pid_copia != :undefined do
                    IO.puts("Soy primario y envio datos a copia")
                  # Fx auxiliar
                  send(
                    estado.pid_copia,
                    {:datos_del_primario, estado.num_vista, estado.datos}
                  )
                end

                estado

              is_ok == true and vista_gv.primario == Node.self() ->
                IO.puts("Soy primario y vista SI validada")
                # Somos primario y hemos validado la vista
                estado = %ServidorSA{estado | num_vista: vista_gv.num_vista}
                estado = %ServidorSA{estado | pid_primario: vista_gv.primario}
                estado = %ServidorSA{estado | pid_copia: vista_gv.copia}
                estado = %ServidorSA{estado | rol: :primario}
                estado

              is_ok == true and vista_gv.copia == Node.self() ->
                IO.puts("Soy copia y vista no validada")
                # Somos copia en la vista valida (is_ok = tentativa == valida)
                estado = %ServidorSA{estado | num_vista: vista_gv.num_vista}
                estado = %ServidorSA{estado | pid_primario: vista_gv.primario}
                estado = %ServidorSA{estado | pid_copia: vista_gv.copia}
                estado = %ServidorSA{estado | rol: :copia}

                # Recibimos los datos del primario (los ha enviado al recibir el dato de que era primario) -> Fx auxiliar
                # Si entramos repetidamente en este sitio, no podemos recibir siempre
                # receive do....after 0 -> si esta en el mailbox ya
                estado =
                  receive do
                    {:datos_del_primario, num_vista, datos} ->
                      estado =
                        if estado.num_vista == num_vista do
                          # Si las vistas coinciden, somos la copia en el num_vista del primario (nos la ha enviado para la vista valida actual)
                          estado = %ServidorSA{estado | datos: datos}
                        else
                          estado
                        end

                      # Devolvemos el estado
                      estado
                  after
                    0 ->
                      estado
                  end

                estado

              is_ok == true and vista_gv.primario != Node.self() and vista_gv.copia != Node.self() ->
                IO.puts("Soy nodo espera y vista no validada")
                # La vista tentativa es la vista valida. Somos un nodo en espera
                estado = %ServidorSA{estado | num_vista: vista_gv.num_vista}
                estado = %ServidorSA{estado | pid_primario: vista_gv.primario}
                estado = %ServidorSA{estado | pid_copia: vista_gv.copia}
                estado = %ServidorSA{estado | rol: :espera}
                estado

              true ->
                # Este caso no actualiza la informacion. La vista no esta validada y somos copia o espera en la tentativa.
                estado
            end

          # El estado esta confirmado
          {nodo_servidor_gv, estado}
      end

    bucle_recepcion_principal(nodo_servidor_gv, estado)
  end

  # --------- Otras funciones privadas que necesiteis .......
  defp realizar_tarea(op, param, estado) do
    {estado, resultado} =
      cond do
        op == :escribe_generido ->
          # param = {clave, nuevo_valor, con_hash (booleano)}
          {clave, nuevo_valor, con_hash} = param
          # Realizamos la operacion
          {estado, resultado} =
            if con_hash == false do
              # Sin hash
              estado = %ServidorSA{estado | datos: Map.put(estado.datos, clave, nuevo_valor)}
              {estado, nuevo_valor}
            else
              # Con hash
              old_value = Map.get(estado.datos, clave, "")
              # Realizamos la operacion
              estado = %ServidorSA{
                estado
                | datos: Map.put(estado.datos, clave, hash(old_value <> nuevo_valor))
              }

              # Devolvemos el estado y el valor de resultado
              {estado, old_value}
            end

          {estado, resultado}

        op == :lee ->
          # param = clave
          {estado, Map.get(estado.datos, param, "")}
      end

    {estado, resultado}
  end
end
