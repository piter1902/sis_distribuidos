#!/bin/bash

# Funcion auxiliar
function join_by { local d=$1; shift; echo -n "$1"; shift; printf "%s" "${@/#/$d}"; }

# Parametros:
# 1. Nombre
# 2. Maquina
# 3. Tipo de maquina {worker, master, cliente, proxy, pool}
# 4. Cookie
# 5. Fichero que contiene la lista de workers (solo se usa si eres pool)
# 6. Name de "ProxyMachine" (solo se usa si eres master)
# 7. Name de "Pool" (solo se usa si eres master)
# 8. Name de "Master" (solo se usa si eres cliente)

if [ $# -ne 8 ]; then
    echo 'El nº de parametros es incorrecto. Uso: bash comando.sh <name> <maquina> <tipo> <cookie> <fichero_workers> <name_proxy_machine> <name_pool> <name_master>'
    exit 1
fi

dir_master="10.1.50.29"
dir_pool="10.1.50.29"
dir_proxy="10.1.50.29"

# Comando a ejecutar para la inicialización de iex
comando="Node.connect(:\"master@$dir_master\");IO.inspect(Node.list());"
case $3 in
    "worker")
        comando=$comando"Process.register(self(), :$1); Worker.init()"
    ;;

    "master")
        comando=$comando"Servidor.server(:\"$7@$dir_pool\",:\"$6@$dir_proxy\")"
    ;;

    "cliente")
        comando=$comando"Cliente.genera_workload({:master,:\"$8@$dir_master\"})"
        #echo 'echo '$comando'|iex --name '$1'@'$2' --cookie '$4' -r "worker.exs" "escenario.exs" 2>/dev/null'
        #exit 1
    ;;

    "proxy")
        #echo $comando'receive do end' | iex --name $1'@'$2 --cookie $4 -r "worker.exs" "escenario.exs" 2>'/dev/null'
        iex --name $1'@'$2 --cookie $4 -r "worker.exs" "escenario.exs" 2>'/dev/null'
        exit 1
    ;;

    "pool")
        lista="[$(join_by , $(cat $5 | tr '\n' ' ' ))]"
        #echo $lista
        comando=$comando"Pool.pool($lista)"
    ;;
esac

# Ejecutamos iex con el comando asociado
echo $comando | iex --name $1'@'$2 --cookie $4 -r "worker.exs" "escenario.exs" 2>'/dev/null'