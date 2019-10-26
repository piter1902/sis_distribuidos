 # AUTOR: Rafael Tolosana Calasanz
 # FICHERO: repositorio.exs
 # FECHA: 17 de octubre de 2019
 # TIEMPO: 1 hora
 # DESCRIPCI'ON:  	Implementa un repositorio para gestionar el enunciado de un trabajo de asignatura.
 # 				El enunciado tiene tres partes: resumen, parte principal y descripci'on de la entrega.
 #				El repositorio consta de un servidor que proporciona acceso individual a cada parte del enunciado,
 #				bien en lectura o bien en escritura				
 
defmodule Repositorio do
	def init do
		repo_server({"", "", ""})
	end
	defp repo_server({resumen, principal, entrega}) do
		{n_resumen, n_principal, n_entrega} = receive do
			{:update_resumen, c_pid, descripcion} -> send(c_pid, {:reply, :ok}); {descripcion, principal, entrega}
			{:update_principal, c_pid, descripcion} -> send(c_pid, {:reply, :ok}); {resumen, descripcion, entrega}
			{:update_entrega, c_pid, descripcion} -> send(c_pid, {:reply, :ok}); {resumen, principal, descripcion}
			{:read_resumen, c_pid} -> send(c_pid, {:reply, resumen}); {resumen, principal, entrega}
			{:read_principal, c_pid} -> send(c_pid, {:reply, principal}); {resumen, principal, entrega}
			{:read_entrega, c_pid} -> send(c_pid, {:reply, entrega}); {resumen, principal, entrega}
		end
		repo_server({n_resumen, n_principal, n_entrega})
	end
end

defmodule LectEscrit do
	#Type indica si lector o escritor
	def init(op_type) do
		procesos = [. . .] #ya hablaremos de como hacemos esto
		procesos_espera = [] #La uso para el perm_delayed
		myTime = Time.utc_now()  #Cogemos marca temporal de la peticion
		pid_thread = spawn(LectEscrit,:receive_petition,[procesos_espera,myTime,op_type]) #Thread encargado de escuchar las REQUEST de los demás procesos
		begin_op(op_type,procesos)
		end_op(pid_thread)
	end

	def begin_op(op_type,procesos) do
		send_petition(procesos,myTime,op_type) #Hacemos REQUEST
		receive_permission(lista_proc)	#Esperamos confirmación de todos procesos 
		#Se supone que estamos dentro
	end
	
	defp end_op(pid_thread) do
		#Pedimos al thread que nos proporcione la lista de delayed
		send(
			pid_thread,
			{:req_delayed,self()}
		)
		receive do #Enviamos permiso a todos que teniamos en delayed
			{:rep_delayed,lista_proc} -> send_permission(lista_proc)
		end
	end

	defp send_petition(lista_proc,myTime,op_type) do
		process = List.first(lista_proc) #Cogemos el primer proceso de la lista
		send(
			process,
			{:request,myTime, self(),op_type}
			)
		 lista_proc = List.delete_at(lista_proc,1)	#Eliminamos ese proceso de la lista
		 if lista_proc != [] do
		 	send_petition(lista_proc,myTime,op_type)
		end
	end

	defp send_permission(lista_proc) do
		process = List.first(lista_proc) #Cogemos el primer proceso de la lista
		send(
			process,
			{:ok,self()}
		)
		lista_proc = List.delete_at(lista_proc,1)	#Eliminamos ese proceso de la lista
		if lista_proc != [] do	#Comprobamos si queda algun proceso del que recibir confirmacion
			receive_permission(lista_proc)
		end
	end
	defp receive_permission(lista_proc) do
		receive do
			{:ok,pid} -> lista_proc = List.delete(lista_proc,pid) #Recibimos confirmacion de todos procesos y eliminamos de la lista
			if lista_proc != [] do	#Comprobamos si queda algun proceso del que recibir confirmacion
				receive_permission(lista_proc)
			end
		end
	end

	#En esta función puedo recibir dos tipos de mensaje:
	# *Peticion de mi proceso padre de que necesita la lista de procesos_bloqueados, con lo que se la enviare
	# *Mensajes de REQUEST del resto de procesos.
	defp receive_petition(procesos_espera,myTime,myOp) do
		receive do
			{:request,other_time, pid, other_op} ->
				prio = (other_time > myTime) && (exclude[myOp,other_op]) #Falta comprobar el estado(out,in)
				if prio do
					procesos_espera = procesos_espera ++ pid
				else #En caso contrario, mandamos PERMISSION
					send(
						pid,
						{:ok,self()}
					)
				end
				receive_petition(procesos_espera,myTime,myOp) #Llamada recursiva

			{:req_delayed, pid} ->
				send(
					pid,
					{:rep_delayed,procesos_espera}
				)
				#Supongo que ya moriría el proceso.
		end
	end
end