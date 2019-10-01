# AUTORES: nombres y apellidos
# NIAs: números de identificacion de los alumnos
# FICHERO: nombre del fichero
# FECHA: fecha de realizacion
# TIEMPO: tiempo en horas de codificación
# DESCRIPCION: breve descripcion del contenido del fichero

import Fib

defmodule Servidor do
  def server() do
    {pid, [op | tail]} =
      receive do
        l -> l
      end

    fib_list =
      cond do
        op == :fib -> Enum.map(tail, fn x -> Fib.fibonacci(x) end)
        op == :fib_tr -> Enum.map(tail, fn x -> Fib.fibonacci_tr(x) end)
        op == :of -> Enum.map(tail, fn x -> Fib.of(x) end)
      end

    send(pid, fib_list)
    server()
  end
end
