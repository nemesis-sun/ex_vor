defmodule ExVor.Event.SiteEvent do
  defstruct site: nil

  def new(%ExVor.Geo.Point{} = p) do
    %ExVor.Event.SiteEvent{site: p}
  end
end