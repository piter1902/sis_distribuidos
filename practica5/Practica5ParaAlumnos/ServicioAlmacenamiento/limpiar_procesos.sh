#!/bin/bash

# Para limpiar los procesos asociados a elixir
#	epmd y beam.smp

for maq in $(cat $1)
do
	echo $maq $(ssh $maq pkill -9 epmd)
	echo $maq $(ssh $maq pkill -9 beam.smp)
done
