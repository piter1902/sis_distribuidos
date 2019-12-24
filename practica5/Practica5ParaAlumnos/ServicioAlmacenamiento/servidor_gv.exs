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
    # Mantenemos el valor de la vista_valida como el struct del modulo ServidorGV -> al inicio = vista_tentativa
    bucle_recepcion(%ServidorGV{}, %ServidorGV{}, latidos_fallidos, nodos_espera, true)
  end

  def init_monitor(pid_principal) do
    send(pid_principal, :procesa_situacion_servidores)
    Process.sleep(@intervalo_latidos)
    init_monitor(pid_principal)
  end

  defp bucle_recepcion(vista_valida, vista_tentativa, latidos_fallidos, nodos_espera, consistente) do
    {vista_valida, vista_tentativa, latidos_fallidos, nodos_espera, consistente} =
      receive do
        {:latido, n_vista_latido, nodo_emisor} ->
          #IO.puts("Soy server_gv y me llega latido de #{inspect(nodo_emisor)}")
          {vista_valida, vista_tentativa, latidos_fallidos, nodos_espera, consistente} =
            if consistente == true do
              {vista_valida, vista_tentativa, latidos_fallidos, nodos_espera, consistente} =
                cond do
                  n_vista_latido == 0 ->
                    # Latido es 0 -> Recaida
                    {vista_tentativa, nodos_espera, latidos_fallidos} =
                      cond do
                        vista_tentativa.primario == :undefined ->
                          IO.puts("Asignando primario a #{inspect(nodo_emisor)} ...")
                          vista_tentativa = %ServidorGV{vista_tentativa | primario: nodo_emisor}

                          vista_tentativa = %ServidorGV{
                            vista_tentativa
                            | num_vista: vista_tentativa.num_vista + 1
                          }

                          {vista_tentativa, nodos_espera, latidos_fallidos}

                        # Asignamos copia si el nodo del que recibimos mensaje no es el primario
                        vista_tentativa.copia == :undefined and
                            vista_tentativa.primario != nodo_emisor ->
                          IO.puts("Asignando copia a #{inspect(nodo_emisor)}...")
                          vista_tentativa = %ServidorGV{vista_tentativa | copia: nodo_emisor}

                          vista_tentativa = %ServidorGV{
                            vista_tentativa
                            | num_vista: vista_tentativa.num_vista + 1
                          }

                          {vista_tentativa, nodos_espera, latidos_fallidos}

                        vista_tentativa.primario == nodo_emisor ->
                          # Recaida del primario
                          # Promocion de copia a primario -> si existe
                          IO.puts("Recaida de primario. Asignando copia como primario ...")
                          vista_tentativa = %ServidorGV{
                            vista_tentativa
                            | primario: vista_tentativa.copia
                          }

                          vista_tentativa = %ServidorGV{
                            vista_tentativa
                            | num_vista: vista_tentativa.num_vista + 1
                          }

                          {vista_tentativa, nodos_espera} =
                            if length(nodos_espera) > 0 do
                              # Añadimos caido a lista de espera sii hay nueva copia asignada
                              # Hay nodos en espera
                              [copia_nueva | resto] = nodos_espera
                              nodos_espera = resto
                              # Lo establecemos como copia
                              vista_tentativa = %ServidorGV{vista_tentativa | copia: copia_nueva}
                              nodos_espera = nodos_espera ++ [nodo_emisor]
                              {vista_tentativa, nodos_espera}
                            else
                              vista_tentativa = %ServidorGV{vista_tentativa | copia: nodo_emisor}

                              {vista_tentativa, nodos_espera}
                            end

                          # Reiniciamos latidos del nodo caido
                          latidos_fallidos =
                            Enum.map(latidos_fallidos, fn {a, b} ->
                              if a == nodo_emisor do
                                {a, 0}
                              else
                                {a, b}
                              end
                            end)

                          {vista_tentativa, nodos_espera, latidos_fallidos}

                        vista_tentativa.copia == nodo_emisor ->
                          # Recaida de copia
                          # Añadimos caido a lista de espera sii hay nueva copia asignada
                          IO.puts("Recaida de copia.Comprobando nodos espera ...")
                          vista_tentativa = %ServidorGV{
                            vista_tentativa
                            | num_vista: vista_tentativa.num_vista + 1
                          }

                          {vista_tentativa, nodos_espera} =
                            if length(nodos_espera) > 0 do
                              # Añadimos caido a lista de espera sii hay nueva copia asignada
                              # Hay nodos en espera
                              [copia_nueva | resto] = nodos_espera
                              nodos_espera = resto
                              # Lo establecemos como copia
                              vista_tentativa = %ServidorGV{vista_tentativa | copia: copia_nueva}
                              nodos_espera = nodos_espera ++ [nodo_emisor]
                              {vista_tentativa, nodos_espera}
                            else
                              vista_tentativa = %ServidorGV{vista_tentativa | copia: nodo_emisor}

                              {vista_tentativa, nodos_espera}
                            end

                          # Reiniciamos latidos del nodo caido
                          latidos_fallidos =
                            Enum.map(latidos_fallidos, fn {a, b} ->
                              if a == nodo_emisor do
                                {a, 0}
                              else
                                {a, b}
                              end
                            end)

                          {vista_tentativa, nodos_espera, latidos_fallidos}

                        vista_tentativa.primario != nodo_emisor and
                            vista_tentativa.copia != nodo_emisor ->
                          nodos_espera = nodos_espera ++ [nodo_emisor]
                          {vista_tentativa, nodos_espera, latidos_fallidos}

                        true ->
                          {vista_tentativa, nodos_espera, latidos_fallidos}
                      end

                    # Aun no ha fallado ningun latido
                    latidos_fallidos = latidos_fallidos ++ [{nodo_emisor, 0}]

                    send(
                      {:servidor_sa, nodo_emisor},
                      {:vista_tentativa, obtener_vista(vista_tentativa),
                       vista_tentativa == vista_valida}
                    )

                    {vista_valida, vista_tentativa, latidos_fallidos, nodos_espera, consistente}

                  n_vista_latido != 0 ->
                    # Funcionamiento normal
                    # validar la vista -> si es el primario y numero de vista == vista tentativa
                    {vista_valida} =
                      if nodo_emisor == vista_tentativa.primario and
                           n_vista_latido == vista_tentativa.num_vista do
                        # Las vistas coinciden -> Se valida la vista tentativa
                        vista_valida = vista_tentativa
                        {vista_valida}
                      else
                        {vista_valida}
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
                      {:servidor_sa, nodo_emisor},
                      {:vista_tentativa, obtener_vista(vista_tentativa),
                       vista_tentativa == vista_valida}
                    )

                    {vista_valida, vista_tentativa, latidos_fallidos, nodos_espera, consistente}
                end
            else
              {vista_valida, vista_tentativa, latidos_fallidos, nodos_espera, consistente}
            end

          {vista_valida, vista_tentativa, latidos_fallidos, nodos_espera, consistente}

        {:obten_vista_valida, pid} ->
          IO.puts("Devolviendo vista valida ...")
          send(
            pid,
            {:vista_valida, obtener_vista(vista_valida), vista_valida == vista_tentativa}
          )

          {vista_valida, vista_tentativa, latidos_fallidos, nodos_espera, consistente}

        :procesa_situacion_servidores ->
          {vista_valida, vista_tentativa, latidos_fallidos, nodos_espera, consistente} =
            if consistente == true do
              # Todos los elementos de latidos_fallidos + 1 latido fallido
              latidos_fallidos = Enum.map(latidos_fallidos, fn {a, b} -> {a, b + 1} end)
              # Guardamos los estados del primario y de la copia
              # Si no se cumple la guarda propuesta, devuelve el átomo especificado en el segundo campo de la función
              estado_primario =
                Enum.find_value(latidos_fallidos, :primario_ok, fn {a, b} ->
                  a == vista_tentativa.primario and b >= @latidos_fallidos
                end)

              estado_copia =
                Enum.find_value(latidos_fallidos, :copia_ok, fn {a, b} ->
                  a == vista_tentativa.copia and b >= @latidos_fallidos
                end)

              # Comprobamos el estado del primario y la copia

              {vista_tentativa, nodos_espera, consistente} =
                cond do
                  estado_primario != :primario_ok and estado_copia != :copia_ok ->
                    # Ambos han caido -> fallo de consistencia
                    consistente = false
                    IO.puts("Fallo de consistencia. Primario y copia caidos.")
                    {vista_tentativa, nodos_espera, consistente}

                  estado_primario != :primario_ok ->
                    IO.puts("Primario caido, comprobando consistencia ...")

                    # Primario ha caido y copia no -> Promocionamos copia y nodo en espera -> copia
                    {vista_tentativa, consistente} =
                      if vista_tentativa.primario != vista_valida.primario do
                        IO.puts("Fallo de consistencia. Primario ha caido sin validar vista.")
                        consistente = false
                        vista_tentativa = %ServidorGV{vista_tentativa | primario: :undefined}
                        vista_tentativa = %ServidorGV{vista_tentativa | copia: :undefined}
                        {vista_tentativa, consistente}
                      else
                        IO.puts("Funcionamiento correcto. Asignando copia como primario.")
                        vista_tentativa = %ServidorGV{
                          vista_tentativa
                          | primario: vista_valida.copia
                        }

                        {vista_tentativa, consistente}
                      end

                    vista_tentativa = %ServidorGV{
                      vista_tentativa
                      | num_vista: vista_tentativa.num_vista + 1
                    }

                    # Buscamos el nuevo nodo copia
                    {vista_tentativa, nodos_espera} =
                      if length(nodos_espera) > 0 do
                        # Hay nodos en espera
                        [copia_nueva | resto] = nodos_espera
                        nodos_espera = resto
                        # Lo establecemos como copia
                        vista_tentativa = %ServidorGV{vista_tentativa | copia: copia_nueva}
                        {vista_tentativa, nodos_espera}
                      else
                        vista_tentativa = %ServidorGV{vista_tentativa | copia: :undefined}

                        {vista_tentativa, nodos_espera}
                      end

                    {vista_tentativa, nodos_espera, consistente}

                  estado_copia != :copia_ok ->
                    IO.puts("Copia caido, comprobando nodos en espera ... ")
                    # Copia ha caido y primario no. Nodos en espera -> copia
                    vista_tentativa = %ServidorGV{
                      vista_tentativa
                      | num_vista: vista_tentativa.num_vista + 1
                    }

                    # Buscamos el nuevo nodo copia
                    {vista_tentativa, nodos_espera} =
                      if length(nodos_espera) > 0 do
                        # Hay nodos en espera
                        [copia_nueva | resto] = nodos_espera
                        nodos_espera = resto
                        # Lo establecemos como copia
                        vista_tentativa = %ServidorGV{vista_tentativa | copia: copia_nueva}
                        {vista_tentativa, nodos_espera}
                      else
                        vista_tentativa = %ServidorGV{vista_tentativa | copia: :undefined}

                        {vista_tentativa, nodos_espera}
                      end
                      IO.puts("vista tentativa: #{inspect(vista_tentativa)}")
                    {vista_tentativa, nodos_espera, consistente}

                  true ->
                    {vista_tentativa, nodos_espera, consistente}
                end

              # Filtramos aquellos nodos que hayan expirado el numero de latidos
              latidos_fallidos =
                Enum.filter(latidos_fallidos, fn {a, b} ->
                  if b < @latidos_fallidos do
                    {a, b}
                  end
                end)

              # Obtenemos una lista de nodos
              nodos_latidos = Enum.map(latidos_fallidos, fn {a, b} -> a end)

              # Filtramos aquellos nodos de la lista que existan aun en latidos
              nodos_espera =
                Enum.filter(nodos_espera, fn x ->
                  if Enum.member?(nodos_latidos, x) do
                    x
                  end
                end)

              # Devolvemos los valores actualizados
              {vista_valida, vista_tentativa, latidos_fallidos, nodos_espera, consistente}
            else
              {vista_valida, vista_tentativa, latidos_fallidos, nodos_espera, consistente}
            end

          {vista_valida, vista_tentativa, latidos_fallidos, nodos_espera, consistente}
      end

    bucle_recepcion(vista_valida, vista_tentativa, latidos_fallidos, nodos_espera, consistente)
  end

  # OTRAS FUNCIONES PRIVADAS VUESTRAS
  defp obtener_vista(vista) do
    # {vista.num_vista, vista.primario, vista.copia}
    vista
  end
end
