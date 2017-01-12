defmodule ExVor.Geo.HLine do
  defstruct y: nil

  def new(y \\ 0) do
    %ExVor.Geo.HLine{y: y}
  end 
end