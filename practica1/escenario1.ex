# AUTORES: nombres y apellidos
# NIAs: números de identificacion de los alumnos
# FICHERO: nombre del fichero
# FECHA: fecha de realizacion
# TIEMPO: tiempo en horas de codificación
# DESCRIPCION: breve descripcion del contenido del fichero

import Fib

defmodule Servidor do
  def server() do
    pid_pool = {:pool, :"pool@10.1.55.251"}
    # Escuchamos peticiones del cliente
    {client, op, limits}=
    receive do
      {client, op, limits} -> {client, op, limits}
    end
    IO.puts("Ha llegado y generamos proceso.")
     spawn(
       Servidor,
       :comunicar,
       [client,pid_pool,op,Enum.to_list limits]
     )

    server()
  end

  defp comunicar(pid_client,pool, op, lista) do
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
    #Ahora nos quedamos unicamente con el pid del worker (ya que lo recibido era algo del tipo: {:w1,PID})
    {at, name_w} = pid_w

    #Generamos el proceso en el nodo y guardamos resultado en la variable resutl
    result=
    Node.spawn(
      name_w,
      Worker,
      :worker,
      [pid_w,pool,op,lista]
    )
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
    
    lista_disponibles = [{:w1, :"w1@10.1.55.251"}, {:w2,:"w2@10.1.55.251"}]
    lista_ocupados = []
    IO.puts("Soy Pool y genero hilo de escucha peticiones")
    spawn(Pool, :escucharPeticiones, [lista_disponibles,lista_ocupados])
    pool(lista_disponibles,lista_ocupados)
  end

  defp pool(disp,ocu) do

    # Esperamos una peticion del master
    IO.puts("Escucho peticion de master")
    pid_master =
    receive do
      {:peti, pid} -> pid
    end

    [head | tail] = disp
    disp = tail
    
    #Marcamos al worker que enviamos como ocupado
    ocu ++ [head]
    IO.puts("Le envio a master el worker #{head} y me queda en disponibles #{tail}")
    # Enviamos un worker al master
    send(
      pid_master,
      {:ok,head}
    )
    IO.puts("Envio realizado")
    pool(disp,ocu)
  end

  def escucharPeticiones(disp,ocu) do
    #Recibimos confirmación de final de los workers
    IO.puts("Estoy en funcion escucharPeticiones")
    pid_worker=
    receive do
      {:fin,pid_worker} -> pid_worker
    end 
    
    IO.puts("Procedemos a desocupar #{pid_worker}")
    #con estas operaciones, marcamos nodo como desocupado
    disp ++ [pid_worker]  
    ocu -- [pid_worker]
    escucharPeticiones(disp,ocu)
  end
end

defmodule Worker do
  def worker(pid_w, pid_p, op, lista) do
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

   #Devolvemos resultado  
   result
    
  end
end