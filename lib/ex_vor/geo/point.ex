defmodule ExVor.Geo.Point do
  defstruct x: nil, y: nil

  def new(x \\ 0, y \\ 0) when is_number(x) and is_number(y) do
    %ExVor.Geo.Point{x: x*1.0, y: y*1.0}
  end 
end