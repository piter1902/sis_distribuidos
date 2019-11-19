#!/bin/bash

# Parametros:
# 1. Nombre
# 2. Maquina
# 3. Tipo de maquina {worker, master, cliente, proxy, pool}
# 4. Cookie
# 5. Fichero que contiene la lista de workers (solo se usa si eres pool)
# 6. IP de "ProxyMachine" (solo se usa si eres master)
# 7. IP de "Pool" (solo se usa si eres master)
# 8. IP de "Master" (solo se usa si eres cliente)

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
echo $comando | iex --name $1'@'$2 --cookie $4 -r "worker.exs" "escenario.exs" 2>'/dev/null'