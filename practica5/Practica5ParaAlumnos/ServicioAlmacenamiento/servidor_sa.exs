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

                    # Recibimos la confirmacion de la copia
                    receive do
                      {:copia_ok} -> nil
                    after
                      1000 ->
                        # Ha saltado el timeout
                        nil
                    end

                    # Enviamos la confirmacion al cliente
                    send(
                      nodo_origen,
                      {:confirmacion}
                    )
                  else
                    # No tenemos una copia. Que devolvemos?
                  end

                estado

              estado.rol == :copia ->
                # Ralizamos la tarea -> Fx auxiliar

                send(
                  nodo_origen,
                  {:copia_ok}
                )

                estado
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

          send(
            {:servidor_gv, nodo_servidor_gv},
            {:latido, n_vista, Node.self()}
          )

          # esperar respuesta del servidor_gv
          {vista_gv, is_ok} =
            receive do
              {:vista_tentativa, vista, encontrado?} -> {vista, encontrado?}
              _otro -> exit(" ERROR: en funcion #latido# de modulo ClienteGV")
            after
              @tiempo_espera_de_respuesta -> {ServidorGV.vista_inicial(), false}
            end

          # Actualizamos el estado en base a la vista tentativa
          estado =
            cond do
              is_ok == false and vista_gv.pid_primario == Node.self() ->
                # Somos primario pero la vista no está validada. (Nos acaban de promocionar)
                # Actualizamos el valor de nuestra copia a la copia actual en el gestor de vistas
                estado.pid_copia = vista_gv.copia

                estado =
                  if vista_gv.copia != :undefined do
                    # Podemos confirmar la vista al tener un nodo copia -> No hay fallo de disponibilidad
                    estado.num_vista = vista_gv.num_vista
                    estado
                  else
                    # No podemos confirmar la vista.
                    estado.num_vista = -1
                    estado
                  end

                estado.pid_primario = Node.self()
                estado.pid_copia = vista_gv.copia
                estado.rol = :primario
                # Transferencia de los datos a la nueva copia -> Fx auxiliar
                estado

              is_ok == true and vista_gv.primario == Node.self() ->
                # Somos primario y hemos validado la vista
                estado.num_vista = vista_gv.num_vista
                estado.pid_primario = vista_gv.primario
                estado.pid_copia = vista_gv.copia
                estado.rol = :primario
                estado

              is_ok == true and vista_gv.copia == Node.self() ->
                # Somos copia en la vista valida (is_ok = tentativa == valida)
                estado.num_vista = vista_gv.num_vista
                estado.pid_primario = vista_gv.primario
                estado.pid_copia = vista_gv.copia
                estado.rol = :copia

                # Recibimos los datos del primario (los ha enviado al recibir el dato de que era primario) -> Fx auxiliar
                estado

              is_ok == true and vista_gv.primario != Node.self() and vista_gv.copia != Node.self() ->
                # La vista tentativa es la vista valida. Somos un nodo en espera
                estado.num_vista = vista_gv.num_vista
                estado.pid_primario = vista_gv.primario
                estado.pid_copia = vista_gv.copia
                estado.rol = :espera
                estado
            end

          # El estado esta confirmado
          {nodo_servidor_gv, estado}

          #   Este es el codigo antiguo pero no lo borro por si acaso
          #   estado =
          #   cond do
          #     is_ok == false and vista_gv.primario == Node.self() ->
          #         # Somos primario pero la vista no está validada. (Nos acaban de promocionar)
          #         # Actualizamos el valor de nuestra copia a la copia actual en el gestor de vistas
          #         estado.copia = vista_gv.copia
          #         # Enviamos el almacen a la copia -> operacion aparte
          #     is_ok == false and vista_gv.copia == Node.self() ->
          #         # Somos copia pero no nos han validado todavia.
          #     (vista_gv.primario != Node.self() and vista_gv.copia != Node.self()) or is_ok == true ->
          #         # Actualizamos el numero de vista porque ha sido validada (is_ok == true)
          #         estado.num_vista = vista_gv.num_vista
          #   end
      end

    bucle_recepcion_principal(nodo_servidor_gv, estado)
  end

  # --------- Otras funciones privadas que necesiteis .......
end
