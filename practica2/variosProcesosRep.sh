#!/bin/bash

#Script encargado de iniciar tantos procesos lectores o escritores como se indique en la invocación
#Usage :  ./variosProcesos.sh <numProcLect> <numProcEscr> <direccionLect> <direccionEscr> <cookie>

#<tipo>: 1 = lectores || 2 = Escritores

temporal="vacio"
if [ $# -ne 9 ]
then
    echo "Uso: ./variosProcesos.sh <numPlectResu> <numPlectPrinci> <numPlectEnt> <numPescResu> <numPescPrinci> <numPescEnt> <direccionLect> <direccionEscr> <cookie>" 1>&2
    exit 1
fi
# Bucle para generar lista de procesos lector en Resumen
lista="["
i=1
while [ $i -le $1 ]
do
    lista+="{:lresu$i,:\"lresu$i@$7\"},"
    i=$(( i + 1))
done

# Bucle para generar lista de procesos lector en Principal
i=1
while [ $i -le $2 ]
do
    lista+="{:lprinci$i,:\"lprinci$i@$7\"},"
    i=$(( i + 1))
done

# Bucle para generar lista de procesos lector en Entrega
i=1
while [ $i -le $3 ]
do
    lista+="{:lentre$i,:\"lentre$i@$7\"},"
    i=$(( i + 1))
done

# Bucle para generar lista de procesos escritor en Resumen
i=1
while [ $i -le $4 ]
do
    lista+="{:wresu$i,:\"wresu$i@$8\"},"
    i=$(( i + 1))
done

# Bucle para generar lista de procesos escritor en Principal
i=1
while [ $i -le $5 ]
do
    lista+="{:wprinci$i,:\"wprinci$i@$8\"},"
    i=$(( i + 1))
done
# Bucle para generar lista de procesos escritor en Entrega
i=1
while [ $i -le $6 ]
do
    lista+="{:wentre$i,:\"wentre$i@$8\"}"
    i=$(( i + 1))
    if [ $i -le $6 ]
    then
        lista+=","
    fi
done
lista+="]"
echo $lista
# Lanzamos procesos lectores en Resumen
i=1
while [ $i -le $1 ]
do
    gnome-terminal -x bash -c "bash $(pwd)/initRep.sh "lresu$i" "$7" ":lresu$i" ":read" '$lista' "$9" ":read_resumen" "repo"  "Modifcio_resumen_$i"; exec bash"
    
    i=$(( i + 1))
done

# Lanzamos procesos lectores en Principal
i=1
while [ $i -le $2 ]
do
    gnome-terminal -x bash -c "bash $(pwd)/initRep.sh "lprinci$i" "$7" ":lprinci$i" ":read" '$lista' "$9" ":read_principal" "repo"  "Modifcio_resumen_$i"; exec bash"
    
    i=$(( i + 1))
done

# Lanzamos procesos lectores en Entrega
i=1
while [ $i -le $3 ]
do
    gnome-terminal -x bash -c "bash $(pwd)/initRep.sh "lentre$i" "$7" ":lentre$i" ":read" '$lista' "$9" ":read_entrega"  "repo"  "Modifcio_resumen_$i"; exec bash"
    
    i=$(( i + 1))
done

# Lanzamos procesos escritores en Resumen
i=1
while [ $i -le $4 ]
do
    gnome-terminal -x bash -c "bash $(pwd)/initRep.sh "wresu$i" "$8" ":wresu$i" ":write" '$lista' "$9" ":update_resumen" "repo"  "Modifcio_resumen_$i"; exec bash"
    
    i=$(( i + 1))
done

# Lanzamos procesos escritores en Principal
i=1
while [ $i -le $5 ]
do
    gnome-terminal -x bash -c "bash $(pwd)/initRep.sh "wprinci$i" "$8" ":wprinci$i" ":write" '$lista' "$9" ":update_principal" "repo" "Modifcio_principal_$i"; exec bash"
    
    i=$(( i + 1))
done

# Lanzamos procesos escritores en Entrega
i=1
while [ $i -le $6 ]
do
    gnome-terminal -x bash -c "bash $(pwd)/initRep.sh "wentre$i" "$8" ":wentre$i" ":write" '$lista' "$9" ":update_entrega" "{:repo,:\"repo@127.0.0.1\"}" "Modifcio_entrega_$i"; exec bash"
    
    i=$(( i + 1))
done
