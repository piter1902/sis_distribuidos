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

#echo 'Process.register(self(),'$3'); LectEscrit.init('$4', '$5')' | iex --name $1'@'$2 --cookie $6 "repositorio.exs"
if [ $4 == ':read' ]; then
    echo 'Process.register(self(),'$3'); Node.connect(:"repo@127.0.0.1"); Pruebas.init_prueba('$4','$5',:read_resumen,{:repo,:"repo@127.0.0.1"},"prueba'$1'")' | iex --name $1'@'$2 --cookie $6 -r "repositorio.exs" "repoPruebas.exs"
else
    echo 'Process.register(self(),'$3'); Node.connect(:"repo@127.0.0.1"); Pruebas.init_prueba('$4','$5',:update_resumen,{:repo,:"repo@127.0.0.1"},"prueba'$1'")' | iex --name $1'@'$2 --cookie $6 -r "repositorio.exs" "repoPruebas.exs"
fi
