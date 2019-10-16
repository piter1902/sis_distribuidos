# AUTORES: nombres y apellidos
# NIAs: números de identificacion de los alumnos
# FICHERO: nombre del fichero
# FECHA: fecha de realizacion
# TIEMPO: tiempo en horas de codificación
# DESCRIPCION: breve descripcion del contenido del fichero

import Fib

defmodule Servidor do
  def server() do
    lista_disponibles = [:"w1@10.1.56.75", :"w1@10.1.56.75",:"w1@10.1.56.75", :"w1@10.1.56.75"]
    lista_ocupados = []
    lista_pendientes = []
    server(disp, ocu, pend)
  end

  def server(disp, ocu, pend) do
    #pid_pool = {:pool, :"pool@10.1.56.75"}
    # Escuchamos peticiones del cliente
    {disp,ocu,pend}=
    receive do
      {client, op, limits} -> 
        if disp != [] do
          [head | tail] = disp
          disp = tail
          ocu = ocu ++ [head]
          spawn(
            Servidor,
            :comunicar,
            [self(),head,client,op,limits]
          )
          {disp,ocu,pend}
        else
          pend = pend ++ [pid]
          IO.puts("Estamos en el caso de no disponibles -> pend = ")
          IO.puts(inspect(pend))
          {disp,ocu,pend}
        end
      {:fin,pid_w} ->
          if pend != [] do
            IO.puts("Hay algun pendiente.")
            # Existe alguien esperando -> Le damos servicio
            [pid_pendiente | resto] = pend
            pend = resto
            spawn(
              Servidor,
              :comunicar,
              [self(),pid_w,pid_pendiente,op,limits]
            )
          {disp,ocu,pend}
        else
          # Lo devolvemos a la lista de disponibles
          IO.puts("No hay ningun pendiente")
          ocu = ocu -- [pid]
          disp = disp ++ [pid]
          {disp,ocu,pend}
        end
    end
    server(disp,ocu,pend)
  end

  def comunicar(pid_server,pid_w,pid_c,op,limits) do
    #Generamos el proceso en el nodo y guardamos resultado en la variable resutl
    
    Node.spawn(
      pid_w,
      Worker,
      :worker,
      [self(),pid_w,pid_server,op,Enum.to_list(limits)]
    )
    
    result=
    receive do
      result -> result
    end

    IO.puts(inspect(result))
    
    send(
      pid_client,
      {:fin,result}
    )
    IO.puts("Muerte de comunicar")
  end
end

defmodule Worker do
  def worker(pid_thread, pid_w, pid_master, op, lista) do
    # Miramos peticion
    IO.puts("Soy el worker #{pid_w}")
    result=
    cond do
      op == :fib -> Enum.map(lista, fn x -> Fib.fibonacci(x) end)
      op == :fib_tr -> Enum.map(lista, fn x -> Fib.fibonacci_tr(x) end)
      op == :of -> Enum.map(lista, fn x -> Fib.of(x) end)
    end
    # Nos ponemos disponibles
    IO.puts("Envio a master que estoy libre")
    send(
      pid_master,
      {:fin,pid_w}
    )

   # Devolvemos resultado -> Enviando a thread
   send(
     pid_thread,
     result
   ) 

  end
end
