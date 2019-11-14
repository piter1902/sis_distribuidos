#!/bin/bash

# Script que prueba que equipos del laboratorio L1.02 estan encendidos (responden al ping)

# La ip de los equipos del laboratorio va de 191 a 210
ip="155.210.154."

for i in $(seq 191 210)
do
	ping -w1 $ip$i >'/dev/null'
	if [ $? -eq 0 ]; then
		echo $ip$i
	fi
done
