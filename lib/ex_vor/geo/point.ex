defmodule ExVor.Geo.Point do
  defstruct x: nil, y: nil, label: nil

  def new(x \\ 0, y \\ 0, l \\ nil) when is_number(x) and is_number(y) do
    %ExVor.Geo.Point{x: x*1.0, y: y*1.0, label: l}
  end 
end