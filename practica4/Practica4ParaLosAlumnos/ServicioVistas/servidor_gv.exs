# Para utilizar IEx.pry
require IEx

defmodule ServidorGV do
  @moduledoc """
      modulo del servicio de vistas
  """

  # Tipo estructura de datos que guarda el estado del servidor de vistas
  # COMPLETAR  con lo campos necesarios para gestionar
  # el estado del gestor de vistas
  defstruct primario: :undefined, copia: :undefined, numVista: 0

  # Constantes
  @latidos_fallidos 4

  @intervalo_latidos 50

  @doc """
      Acceso externo para constante de latidos fallios
  """
  def latidos_fallidos() do
    @latidos_fallidos
  end

  @doc """
      acceso externo para constante intervalo latido
  """
  def intervalo_latidos() do
    @intervalo_latidos
  end

  @doc """
      Generar un estructura de datos vista inicial
  """
  def vista_inicial() do
    %{num_vista: 0, primario: :undefined, copia: :undefined}
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
  @spec startService(node) :: boolean
  def startService(nodoElixir) do
    NodoRemoto.esperaNodoOperativo(nodoElixir, __MODULE__)

    # Poner en marcha el código del gestor de vistas
    Node.spawn(nodoElixir, __MODULE__, :init_sv, [])
  end

  # ------------------- FUNCIONES PRIVADAS ----------------------------------

  # Estas 2 primeras deben ser defs para llamadas tipo (MODULE, funcion,[])
  def init_sv() do
    Process.register(self(), :servidor_gv)

    # otro proceso concurrente
    spawn(__MODULE__, :init_monitor, [self()])

    #### VUESTRO CODIGO DE INICIALIZACION
    # Lista de los nodos que estan en espera -> Ni primario ni copia
    nodos_espera = []

    # Lista que registra los latidos no respondidos de cada nodo (primario, copia y todos los de la lista de espera)
    # Tendra una estructura [{nombre_nodo1, numero_latidos_fallidos1}, {nombre_nodo2, numero_latidos_fallidos2}, ... , {nombre_nodoN, numero_latidos_fallidosN}]
    latidos_fallidos = []
    # Al inicio vista_valida = vista_tentativa -> Ambos campos son :undefined
    # Mantenemos el valor de la vista_valida en el struct del modulo ServidorGV -> al inicio = vista_tentativa
    bucle_recepcion(vista_inicial(), latidos_fallidos, nodos_espera)
  end

  def init_monitor(pid_principal) do
    send(pid_principal, :procesa_situacion_servidores)
    Process.sleep(@intervalo_latidos)
    init_monitor(pid_principal)
  end

  defp bucle_recepcion(vista_tentativa, latidos_fallidos, nodos_espera) do
    {vista_tentativa, latidos_fallidos, nodos_espera} =
      receive do
        {:latido, n_vista_latido, nodo_emisor} ->
          nil

        ### VUESTRO CODIGO

        {:obten_vista_valida, pid} ->
          nil

        ### VUESTRO CODIGO

        :procesa_situacion_servidores ->
          nil

          ### VUESTRO CODIGO
      end

    bucle_recepcion(vista_tentativa, latidos_fallidos, nodos_espera)
  end

  # OTRAS FUNCIONES PRIVADAS VUESTRAS
end
