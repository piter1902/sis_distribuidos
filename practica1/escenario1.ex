import Fib
defmodule Servidor do
	def server() do
		[op | tail] = receive do	
            l -> l
        end
        
        empty_list = cond do
            op == :fib -> Enum.map(tail, fn x -> Fib.fibonacci x end) 
        end

