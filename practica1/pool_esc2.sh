#!/bin/bash

# $1 -> IP de la maquina, $2 -> nombre de la cookie

echo 'c "fibonaccis.exs";c"escenario2.exs";Pool.pool' | iex --name pool@$1 --cookie $2


