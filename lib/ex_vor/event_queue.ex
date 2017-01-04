defmodule ExVor.EventQueue do 
  defstruct q: HeapQueue.new

  def new do
    %ExVor.EventQueue{}
  end

  
end