import Fib
defmodule Prueba do
    def init() do
        receive do
            {:fib, numero, cpid} -> resultado = Fib.of(numero)
                                    send(
                                        cpid,
                                        {:resultado,resultado}
                                    )
        end
        init()
    end
end