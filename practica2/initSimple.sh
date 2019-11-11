#!/bin/bash

# Script que inicia el modulo de lectores/escritores
# Usage: bash init.sh <name> <direccion> <nombre_registrar> <tipo = {:read | :write}> <lista de procesos> <cookie>

if [ $# -ne 6 ]; then
    echo "Usage: ./init.sh <name> <direccion> <nombre_registrar> <tipo = {:read | :write}> <lista de procesos> <cookie>" 1>&2
    exit 1
fi

i=0
for el in $@; do
    i=$((i + 1))
    echo $i : $el

done

#echo 'Process.register(self(),'$3'); LectEscrit.init('$4', '$5')'

echo 'Process.register(self(),'$3'); LectEscrit.init('$4', '$5')' | iex --name $1'@'$2 --cookie $6 "repositorio.exs"
