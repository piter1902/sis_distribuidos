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
    
    lista_disponibles = [{:w1, :"w1@10.1.62.237"}, {:w2,:"w2@10.1.62.237"}]
    lista_ocupados = []
    spawn(Pool, :escucharPeticiones, [lista_disponibles,lista_ocupados])
    pool(lista_disponibles,lista_ocupados)
  end

  defp pool(disp,ocu) do

    # Esperamos una peticion del master
    pid_master =
    receive do
      {:peti, pid} -> pid
    end
    [head | tail] = disp
    disp = tail
    
    #Marcamos al worker que enviamos como ocupado
    ocu ++ [head]

    # Enviamos un worker al master
    send(
      pid_master,
      {:ok,head}
    )

    pool(disp,ocu)
  end

  def escucharPeticiones(disp,ocu) do
    #Recibimos confirmación de final de los workers
    pid_worker=
    receive do
      {:fin,pid_worker} -> pid_worker
    end 
    
    #con estas operaciones, marcamos nodo como desocupado
    disp ++ [pid_worker]  
    ocu -- [pid_worker]
    escucharPeticiones(disp,ocu)
  end
end

defmodule Worker do
  def worker(pid_w, pid_p, op, lista) do
    # Miramos peticion


    # Esperamos a una peticion del pool

    # Nos ponemos disponibles
    
  end
end