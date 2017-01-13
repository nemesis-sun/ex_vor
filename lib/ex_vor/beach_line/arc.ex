defmodule ExVor.BeachLine.Arc do

  # the arc is a part the parabola 
  # determined by the site (parabola's focus) and the sweep line (parabola's directrix)
  # sweep line changes so only site should be stored here
  defstruct site: nil
  
  def new(%ExVor.Geo.Point{} = site) do
    %ExVor.BeachLine.Arc{site: site}
  end
end