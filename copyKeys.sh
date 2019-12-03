#!/bin/bash

if [ $# -lt 2 ] 
then
    echo Metodo de empleo: ./copyKeys.sh IP_inicio IP_Final
    exit 1
fi

addr=$(echo $1 | cut -d "." -f 1-3)
ip=$(echo $1 | cut -d "." -f 4)
lastIp=$(echo $2 | cut -d "." -f 4)
rm "IPs.txt" &> /dev/null

while [ $ip -le $lastIp ]
do
	echo "Probando IP $addr.$ip"
	ping -c 1 "$addr.$ip" &> /dev/null    				#comprueba que la maquina correspondiente a la ip esta disponible
	if [[ $? -eq 0 ]]
	then
		echo "Disponible"
		echo "$addr.$ip " >> IPs.txt
	else
		echo "No disponible"
	fi
	ip=$((ip+1))
done

echo
echo "Copiando claves..."
echo

cat "IPs.txt" | while read ip
do
	echo "Copiando a $ip"
	ssh-copy-id -i ~/.ssh/sis_dis_pr5.pub a755742@$ip 			#Cambiar nombre de clave por nombre de clave propia
done

echo
echo "Tarea finalizada"

		
