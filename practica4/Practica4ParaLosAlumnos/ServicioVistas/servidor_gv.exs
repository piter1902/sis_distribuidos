# Para utilizar IEx.pry
require IEx

defmodule ServidorGV do
  @moduledoc """
      modulo del servicio de vistas
  """

  # Tipo estructura de datos que guarda el estado del servidor de vistas
  # COMPLETAR  con lo campos necesarios para gestionar
  # el estado del gestor de vistas
  defstruct primario: :undefined, copia: :undefined, num_vista: 0

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
          cond do
            n_vista_latido == 0 ->
              # Latido es 0 -> Recaida
              cond do
                ServidorGV.primario() == :undefined ->
                  vista_tentiva = %{vista_tentativa | primario: nodo_emisor}

                ServidorGV.copia() == :undefined ->
                  vista_tentiva = %{vista_tentativa | copia: nodo_emisor}

                true ->
                  nodos_espera = nodos_espera ++ [nodo_emisor]
              end

              # Aun no ha fallado ningun latido
              latidos_fallidos = latidos_fallidos ++ [{nodo_emisor, 0}]

            # Latido != 0
            n_vista_latido == -1 ->
              # nodo_emisor es primario pero no confirma la vista
              nil

            n_vista_latido > 0 ->
              # validar la vista -> si es el maestro y numero de vista == vista tentativa
              if nodo_emisor == vista_tentativa.primario do
                if n_vista_latido == vista_tentativa.num_vista do
                  # Las vistas coinciden -> Se valida la vista tentativa
                  ServidorGV = vista_tentativa
                end
              end

              # Resetamos los latidos fallidos de la lista a 0 para el nodo nodo_emisor
              latidos_fallidos =
                Enum.map(latidos_fallidos, fn {a, b} ->
                  if a == nodo_emisor do
                    {a, 0}
                  else
                    {a, b}
                  end
                end)

              # Le devolvemos la vista tentativa
              send(
                nodo_emisor,
                obtener_vista(vista_tentativa)
              )
          end

        ### VUESTRO CODIGO

        {:obten_vista_valida, pid} ->
          send(
            pid,
            obtener_vista(ServidorGV)
          )

        :procesa_situacion_servidores ->
          # Todos los elementos de latidos_fallidos + 1 latido fallido
          latidos_fallidos = Enum.map(latidos_fallidos, fn {a, b} -> {a, b + 1} end)
          # Guardamos los estados del primario y de la copia
          estado_primario =
            Enum.filter(latidos_fallidos, fn {a, b} ->
              if a == vista_tentativa.primario and b >= @latidos_fallidos do
              end
            end)

          estado_copia =
            Enum.filter(latidos_fallidos, fn {a, b} ->
              if a == vista_tentativa.copia and b >= @latidos_fallidos do
              end
            end)

          # Filtramos aquellos nodos que hayan expirado el numero de latidos
          latidos_fallidos = Enum.filter()
      end

    bucle_recepcion(vista_tentativa, latidos_fallidos, nodos_espera)
  end

  # OTRAS FUNCIONES PRIVADAS VUESTRAS
  defp obtener_vista(vista) do
    {vista.num_vista(), vista.primario(), vista.copia()}
  end
end
