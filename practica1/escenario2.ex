# AUTORES: nombres y apellidos
# NIAs: números de identificacion de los alumnos
# FICHERO: nombre del fichero
# FECHA: fecha de realizacion
# TIEMPO: tiempo en horas de codificación
# DESCRIPCION: breve descripcion del contenido del fichero

import Fib

defmodule Servidor do
  def server() do
  end
end

defmodule Pool do
  def pool() do
    lista_disponibles = []
    spawn(:escucharPeticiones, lista_disponibles)
    pool(lista_disponibles)
  end

  defp pool(list) do
    pool(list)
  end

  def escucharPeticiones(list) do
    escucharPeticiones(list)
  end
end
