# AUTORES: nombres y apellidos
# NIAs: números de identificacion de los alumnos
# FICHERO: nombre del fichero
# FECHA: fecha de realizacion
# TIEMPO: tiempo en horas de codificación
# DESCRIPCION: breve descripcion del contenido del fichero

import Fib

defmodule Servidor do
  def server() do
    pid_pool = {:pool, :"pool@10.1.56.75"}
    # Escuchamos peticiones del cliente
    {client, op, limits}=
    receive do
      {client, op, limits} -> {client, op, limits}
    end
    IO.puts("Ha llegado y generamos proceso.")
    IO.puts(inspect(client))
     spawn(
       Servidor,
       :comunicar,
       [client,pid_pool,op,Enum.to_list limits]
     )

    server()
  end

  def comunicar(pid_client,pool, op, lista) do
    #Pide worker al pool
    IO.puts("Generado proceso comunicar y enviamos a pool")
    send(
      pool,
      {:peti,self()}
    )
    #Recibimos el worker con el que trabajaremos
    pid_w=
    receive do
      {:ok, pid_w} -> pid_w
    end
    IO.puts("Hemos recibido worker, con pid #{pid_w}" )

    #Generamos el proceso en el nodo y guardamos resultado en la variable resutl
    
    Node.spawn(
      pid_w,
      Worker,
      :worker,
      [self(),pid_w,pool,op,lista]
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

defmodule Pool do
  
  def pool() do
    lista_disponibles = [:"w1@10.1.56.75", :"w1@10.1.56.75", :"w1@10.1.56.75", :"w1@10.1.56.75"]
    lista_ocupados = []
    lista_pendientes = []
    IO.puts("Soy Pool y genero hilo de escucha peticiones")
    pool(lista_disponibles,lista_ocupados, lista_pendientes)
  end

  defp pool(disp,ocu,pend) do

    # Esperamos una peticion del master
    IO.puts("Escucho peticion de master")
    
    {disp,ocu,pend}=
    receive do
      {:peti, pid} -> 
        if disp != [] do
          IO.puts("Aqui llego: separare head y tail")
          [head | tail] = disp
          disp = tail
          IO.puts("Aqui llego, voy a anadir head a ocupados.")
          #Marcamos al worker que enviamos como ocupado
          ocu = ocu ++ [head]
          IO.puts("Le envio a master el worker #{head} y me queda en disponibles ")
          # Enviamos un worker al master
          send(
            pid,
            {:ok,head}
          )
          IO.puts("Envio realizado")
          IO.puts(inspect(disp))
          {disp,ocu,pend}
        else
          pend = pend ++ [pid]
          IO.puts("Estamos en el caso de no disponibles -> pend = ")
          IO.puts(inspect(pend))
          {disp,ocu,pend}
        end        
      {:fin, pid} -> 
        IO.puts("Nos ha llegado peticion de fin del worker #{pid}")
        # Fin de worker -> anadimos a disponible
        # Comprobamos si hay alguien esperando        
        if pend != [] do
          IO.puts("Hay algun pendiente.")
          # Existe alguien esperando -> Le damos servicio
          [pid_pendiente | resto] = pend
          pend = resto
          send(
            pid_pendiente,
            {:ok, pid}
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

    IO.puts(inspect(disp))
    IO.puts(inspect(ocu))
    IO.puts(inspect(pend))

    pool(disp,ocu,pend)
  end

end

defmodule Worker do
  def worker(pid_master, pid_w, pid_p, op, lista) do
    # Miramos peticion
    IO.puts("Soy el worker #{pid_w}")
    result=
    cond do
      op == :fib -> Enum.map(lista, fn x -> Fib.fibonacci(x) end)
      op == :fib_tr -> Enum.map(lista, fn x -> Fib.fibonacci_tr(x) end)
      op == :of -> Enum.map(lista, fn x -> Fib.of(x) end)
    end
    # Nos ponemos disponibles
    IO.puts("Envio a pool que estoy libre")
    send(
      pid_p,
      {:fin,pid_w}
    )

   
   # Devolvemos resultado -> Enviando a master
   send(
     pid_master,
     result
   ) 

  end
end
