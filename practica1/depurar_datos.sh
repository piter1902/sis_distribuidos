#!/bin/bash

# Script que depura los ficheros de datos con estructura:
#   NE: XX
#   TiempoEnvio

if [ $# -ne 2 ]; then
    echo "Usage ./depurar_datos.sh <fichero_depurar> <fichero_salida>"
    exit 1
fi

oIFS=$IFS
IFS=$'\n'
i=0
salida=""
for line in $(cat $1)
do
    echo "linea $i : $line"
    
    #echo $line | egrep '^NE: [[:digit:]]+$' > '/dev/null'
    echo "$line" | egrep '^[[:digit:]]+$'
    if [ $? -eq 0 ]; then
        # Coincide con el patron dado
        # echo "PATRON"
        #linea_escribir=$(echo $line | cut -d' ' -f2)
        # echo "$linea_escribir"
        #salida+="$linea_escribir;"
        salida+="$line\n"
    else
        # No coincide con el patron -> TiempoEnvio
        #salida+="$line\n"
        i=$(( i + 1 ))
        salida+="$i;"
    fi
done
# Escribimos $salida en $2
IFS=$oIFS
echo -e $salida > $2