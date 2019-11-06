#!/bin/bash

#Script encargado de iniciar tantos procesos lectores o escritores como se indique en la invocación
#Usage :  ./variosProcesos.sh <numProcLect> <numProcEscr> <direccionLect> <direccionEscr> <cookie>

#<tipo>: 1 = lectores || 2 = Escritores

if [ $# -ne 5 ]
then
    echo "Uso: ./variosProcesos.sh <numProcLect> <numProcEscr> <direccionLect> <direccionEscr> <cookie>" 1>&2
    exit 1
fi
# Bucle para generar lista de procesos lector
lista="["
i=1
while [ $i -le $1 ]
do
    lista+="{:l$i,:\"l$i@$3\"},"
    i=$(( i + 1))
done

i=1
while [ $i -le $2 ]
do
    lista+="{:w$i,:\"w$i@$4\"}"
    i=$(( i + 1))
    if [ $i -gt $2 ]
    then
        lista+="]"
    else
        lista+=","
    fi
done

echo $lista
# Lanzamos procesos lectores
i=1
while [ $i -le $1 ]
do
    gnome-terminal -x bash -c "bash $(pwd)/init.sh "l$i" "$3" ":l$i" ":read" '$lista' "$5"; exec bash"
    sleep 0.001
    i=$(( i + 1))
done

# Lanzamos procesos escritores
i=1
while [ $i -le $2 ]
do
    gnome-terminal -x bash -c "bash $(pwd)/init.sh "w$i" "$3" ":w$i" ":write" '$lista' "$5"; exec bash"
    sleep 0.001
    i=$(( i + 1))
done