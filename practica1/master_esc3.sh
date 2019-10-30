#!/bin/bash

# $1 -> IP de la maquina, $2 -> nombre de la cookie, $3 -> Direccion del pool

echo 'c "fibonaccis.exs";c"escenario3.ex";Servidor.server :"pool@'$3'"' | iex --name master@$1 --cookie $2


