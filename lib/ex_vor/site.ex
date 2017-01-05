defmodule ExVor.Site do
  defstruct x: nil, y: nil

  def new(x, y) when is_number(x) and is_number(y) do
    %ExVor.Site{x: x*1.0, y: y*1.0}
  end
end