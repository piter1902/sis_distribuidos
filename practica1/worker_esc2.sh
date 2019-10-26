#!/bin/bash

# $1 -> IP de la maquina, $2 -> nombre de la cookie, $3 -> numero de worker

echo 'c "fibonaccis.exs";c"escenario2.exs"' | iex --name w$3@$1 --cookie $2


