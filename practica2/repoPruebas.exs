# AUTOR: Pedro Tamargo -  Juan José Tambo 
# NIAs: 
# FICHERO: repositorio.exs
# FECHA: 11 de noviembre de 2019
# TIEMPO: 3 horas
# DESCRIPCI'ON:  	Implementa un repositorio para gestionar el enunciado de un trabajo de asignatura.
# 				El enunciado tiene tres partes: resumen, parte principal y descripci'on de la entrega.
# 				El repositorio consta de un servidor que proporciona acceso individual a cada parte del enunciado,
# 				bien en lectura o bien en escritura				

import Repositorio
import LectEscrit

defmodule Pruebas do
  def init_prueba(op_type, procesos, where, pid_repositorio, texto) do
    #La función init inicializa el sistema y devuelve parámetros necesarios en funciones begin_op y end_op
    {procesos_req, pid_servidor, pid_thread, pid_mutex} = init(op_type, procesos)

    #Zona pre-protocol
    begin_op(op_type, procesos_req, pid_servidor, pid_thread, pid_mutex)
    
    #En este punto, el proceso se encuentra en sección crítica
    #Muestra por pantalla el momento exacto en el que entra en SC
    IO.inspect(Time.utc_now())
    
    #Comprueba si es un proceso de lectura o escritura
    if  op_type == :write do
      IO.puts("Enviando a repo y soy writer")
      #Si es un proceso de escritura, envía a repositorio el texto a modificar y el lugar (entrega, resumen o principal)
      send(
          pid_repositorio,
          {where, self(), texto}
      )
      #Recibe ACK de respositorio
      receive do
        {:reply, :ok} -> nil
      end
    else
      IO.puts("Enviando a repo y soy lector")
      #Si es un proceso de escritura, envía a repositorio la solicitud de leer sobre una parte en concreto (entrega, resumen o principal)
      send(
        pid_repositorio,
        {where, self()}
      )
      #Recibe ACK de respositorio y muestra por pantalla el texto sobre el que ha solicitado lectura
      receive do
        {:reply, texto} -> IO.puts("Valor de #{where} es #{texto}")
      end
    end
    #Zona de Post-protocol
    end_op(pid_thread, pid_servidor)
    #Acabamos procesos
    end_process(pid_servidor, pid_thread, pid_mutex)
  end
end