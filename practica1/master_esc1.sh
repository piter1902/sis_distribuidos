#!/bin/bash

# $1 -> IP de la maquina, $2 -> nombre de la cookie

echo 'c "fibonaccis.exs";c"escenario1.exs";Servidor.server' | iex --name master@$1 --cookie $2


