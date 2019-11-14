#!/bin/bash

# Script que inicia el modulo de lectores/escritores
# Usage: bash init.sh <name> <direccion> <nombre_registrar> <tipo = {:read | :write}> <lista de procesos> <cookie>

if [ $# -ne 9 ]; then
    echo "Usage: ./initRep.sh <name> <direccion> <nombre_registrar> <tipo = {:read | :write}> <lista de procesos> <cookie> <where> <pid_repo> <texto>" 1>&2
    exit 1
fi

# i=0
# for el in $@; do
#     i=$((i + 1))
#     echo $i : $el
# done

#echo 'Process.register(self(),'$3'); LectEscrit.init('$4', '$5')'
# Pruebas.init_prueba('$4', '$5', '$7', '$8', '$9')'
echo 'Node.connect(:"repo@127.0.0.1"); Process.register(self(),'$3'); c "repositorio.exs"; c "repoPruebas.exs"; Process.sleep(2000);Pruebas.init_prueba('$4', '$5', '$7', {:repo,:"repo@127.0.0.1"}, '$9')' | iex --name $1'@'$2 --cookie $6 2>/dev/null
