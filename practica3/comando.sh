#!/bin/bash

# Parametros:
# 1. Nombre
# 2. Maquina
# 3. Tipo de maquina {worker, master, cliente, proxy, pool}
# 4. Cookie
# 5. Fichero que contiene la lista de workers (solo se usa si eres pool)
# 6. Name de "ProxyMachine" (solo se usa si eres master)
# 7. Name de "Pool" (solo se usa si eres master)
# 8. Name de "Master" (solo se usa si eres cliente)

if [ $? -ne 8 ]; then
    echo 'El nº de parametros es incorrecto. Uso: bash comando.sh <name> <maquina> <tipo> <cookie> <fichero_workers> <name_proxy_machine> <name_pool> <name_master>'
    exit 1
fi

# Comando a ejecutar para la inicialización de iex
comando=""
case $3 in
    "worker")
        comando="Process.register(self(), :$1); Worker.init()"
    ;;

    "master")
        comando="Servidor.server($7,$6)"
    ;;

    "cliente")
        comando="Servidor.genera_workload($8)"
    ;;

    "proxy")
        comando=""
    ;;

    "pool")
        comando="Pool.pool($(cat $5))"
    ;;
esac

# Ejecutamos iex con el comando asociado
echo $comando | iex --name $1'@'$2 --cookie $4 -r "worker.exs" "escenario.exs" 2>'/dev/null'