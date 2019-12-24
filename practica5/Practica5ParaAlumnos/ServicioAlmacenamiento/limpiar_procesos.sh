#!/bin/bash

# Para limpiar los procesos asociados a elixir
#	epmd y beam.smp

pkill -9 epmd
pkill -9 beam.smp
