#!/bin/bash

# Script que inicia el modulo de lectores/escritores
# Usage: bash init.sh <name> <direccion> <nombre_registrar> <tipo = {:read | :write}> <lista de procesos> <cookie>


echo 'Process.register(self(),'$3');c "repositorio.exs"; LectEscrit.init('$4', '$5')' | iex --name "$1@$2" --cookie $6