defmodule ExVor.BeachLine.BreakPoint do
  # represents the break point between 2 parabolas
  # it can be determined by the 2 sites that play as the parabolas' focuses
  # sweep line always changes so it is not start
  defstruct from_site: nil, to_site: nil

  def new(%ExVor.Geo.Point{}=from_site, %ExVor.Geo.Point{}=to_site) do
    %ExVor.BeachLine.BreakPoint{from_site: from_site, to_site: to_site}
  end
end