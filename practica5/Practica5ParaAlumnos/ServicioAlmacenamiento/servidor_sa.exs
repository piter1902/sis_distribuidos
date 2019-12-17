Code.require_file("#{__DIR__}/cliente_gv.exs")

defmodule ServidorSA do
  # estado del servidor
  # Si rol: :primario, para poder contestar peticiones, copia debe ser != :undefined, en caso contrario,
  #         se para el sistema por fallo de disponibilidad.
  defstruct rol: :undefined, num_vista: 0, pid_copia: :undefined

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
    send(pid_principal, :envia_latido)
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
            # Solo podemos contestar si tenemos copia
            if estado.copia != :undefined do

            end

        # ----------------- vuestro código

        # Mensaje del thread para enviar latido
        {:envia_latido} ->
          send(
            {:servidor_gv, nodo_servidor_gv},
            {:latido, estado.num_vista, Node.self()}
          )

          # esperar respuesta del servidor_gv
          {vista_gv, is_ok} =
          receive do
            {:vista_tentativa, vista, encontrado?} -> {vista, encontrado?}
            _otro -> exit(" ERROR: en funcion #latido# de modulo ClienteGV")
          after
            @tiempo_espera_de_respuesta -> {ServidorGV.vista_inicial(), false}
          end
          estado =
          cond do
            is_ok == false and vista_gv.primario == Node.self() ->
                #Somos primario pero la vista no está validada. (Nos acaban de promocionar)
                # Actualizamos el valor de nuestra copia a la copia actual en el gestor de vistas
                estado.copia = vista_gv.copia

          end

      end

    bucle_recepcion_principal(nodo_servidor_gv, estado)
  end

  # --------- Otras funciones privadas que necesiteis .......
end
