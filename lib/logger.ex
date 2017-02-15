defmodule ExVor.Logger do

  defmacro __using__(_) do
    quote do
      defp print(message, level) do
        module_name = String.replace("#{__MODULE__}", "Elixir.","",global: false)
        IO.puts "[#{module_name}][#{level}]: #{message}"
      end

      defp debug(message) do
        print(message, "DEBUG")
      end

      defp info(message) do
        print(message, "INFO")
      end
    end
  end
end