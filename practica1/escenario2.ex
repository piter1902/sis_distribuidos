# AUTORES: nombres y apellidos
# NIAs: números de identificacion de los alumnos
# FICHERO: nombre del fichero
# FECHA: fecha de realizacion
# TIEMPO: tiempo en horas de codificación
# DESCRIPCION: breve descripcion del contenido del fichero

import Fib

defmodule Servidor do
  def server() do
    # Escuchamos peticiones del cliente

    # Enviamos la peticion al pool

    # Enviamos respuesta a cliente
    server()
  end
end

defmodule Pool do
  def pool() do
    lista_disponibles = []
    spawn(:escucharPeticiones, lista_disponibles)
    pool(lista_disponibles)
  end

  defp pool(list) do
    # Esperamos una peticion del master

    # Enviamos un worker al master

    pool(list)
  end

  def escucharPeticiones(list) do
    escucharPeticiones(list)
  end
end

defmodule Worker do
  def worker() do
    # Miramos peticion

    # Esperamos a una peticion del pool

    # Nos ponemos disponibles
    worker()
  end
end