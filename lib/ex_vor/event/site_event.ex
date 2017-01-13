defmodule ExVor.Event.SiteEvent do
  defstruct x: nil, y: nil, site: nil

  def new(%ExVor.Geo.Point{} = p) do
    %ExVor.Event.SiteEvent{x: p.x, y: p.y, site: p}
  end
end