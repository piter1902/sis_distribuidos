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
		procesos = [] #ya hablaremos de como hacemos esto
		procesos_espera = [] #La uso para el perm_delayed
		myTime = Time.utc_now()  #Cogemos marca temporal de la peticion
		estado = :out
		pid_servidor = spawn(LectEscrit,:server_variables,[procesos_espera, estado, myTime])
		pid_thread = spawn(LectEscrit,:receive_petition,[procesos_espera,myTime,op_type,pid_servidor]) #Thread encargado de escuchar las REQUEST de los demás procesos
		begin_op(op_type,procesos,myTime,estado,pid_servidor)
		#Procedemos a recibir el valor de "estado"
		estado =
		receive do
			{:state, estado} -> estado
		end
		end_op(pid_thread,estado,pid_servidor)	
	end

	defp begin_op(op_type,procesos, myTime,estado,pid_servidor) do
		send(
			pid_servidor,
			{:get,:tiempo,self()}
		)
		myTime =
		receive do
			{:ack, myTime} -> myTime
		end
		myTime = myTime + 1
		send(
			pid_servidor,
			{:set,:tiempo,myTime}
		)
		send_petition(procesos,myTime,op_type) #Hacemos REQUEST
		receive_permission(procesos)	#Esperamos confirmación de todos procesos
		estado = :in
		#Actualizamos valor a servidor de variables
		send(
			pid_servidor,
			{:set,:estado,estado}
		)
		#Se supone que estamos dentro
	end
	
	defp end_op(pid_thread,estado,pid_servidor) do
		#Pedimos al thread que nos proporcione la lista de delayed
		send(
			pid_servidor,
			{:get,:procesos,self()}
		)
		receive do
			{:ack,procesos_espera} -> send_permission(procesos_espera)
		end
		#Hacemos que thread "receive_petition" acabe
		send(
			pid_thread,
			{:fin_operacion}
		)
		#Hacemos que servidor de variables acabe
		send(
			pid_servidor,
			{:fin_operacion}
		)
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
	# *Peticion de mi proceso padre de que necesita la lista de procesos_espera con lo que se la enviare
	# *Mensajes de REQUEST del resto de procesos.
	defp receive_petition(procesos_espera,myTime,myOp,pid_servidor) do
		exclude = [[]]
		receive do
			{:request,other_time, pid, other_op} ->
				send(
					pid_servidor,
					{:get,:tiempo,self()}
				)
				myTime=
				receive do
					{:ack,myTime} -> myTime
				end
				myTime = Enum.max([myTime,other_time])
				#Actualizamos valor a servidor de variables
				send(
					pid_servidor,
					{:set,:tiempo,myTime}
				)
				#Pedimos valor del estado a servidor de variables
				send(
					pid_servidor,
					{:get,:estado,self()}
				)
				estado=
				receive do
					{:ack,estado} -> estado
				end
				prio = (estado != :out) && (other_time > myTime) && (exclude[myOp][other_op]) #Falta comprobar el estado(out,in)
				if prio do
					procesos_espera = procesos_espera ++ pid
					#Actualizamos valor a servidor de variables
					send(
						pid_servidor,
						{:set,:procesos, procesos_espera}
					)
				else #En caso contrario, mandamos PERMISSION
					send(
						pid,
						{:ok,self()}
					)
				end
				receive_petition(procesos_espera,myTime,myOp,pid_servidor) #Llamada recursiva
			
			{:fin_operacion} ->
				#Hemos recibido indicación de acabar
		end
	end

	defp server_variables(procesos_espera, estado, myTime) do
		receive do
			{:get, var, pid} ->
				case var do
					:procesos ->
						send(
							pid,
							{:ack, procesos_espera}
						)
					:estado ->
						send(
							pid,
							{:ack, estado}
						) 
					:tiempo ->
						send(
							pid,
							{:ack, myTime}
						)
				end
				server_variables(procesos_espera, estado, myTime)
			{:set, var, nuevo_valor} ->
				case var do
					:procesos ->
						procesos_espera = nuevo_valor
					:estado ->
						estado = nuevo_valor
					:tiempo ->
						myTime = nuevo_valor
				end
				server_variables(procesos_espera, estado, myTime)

			{:fin_operacion} ->
		end
	end
end