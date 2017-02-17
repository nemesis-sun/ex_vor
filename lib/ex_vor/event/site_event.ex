defmodule ExVor.Event.SiteEvent do
  defstruct site: nil

  def new(%ExVor.Geo.Point{} = p) do
    %ExVor.Event.SiteEvent{site: p}
  end
end

defimpl String.Chars, for: ExVor.Event.SiteEvent do
  def to_string(s_event) do
    "SiteEvent[#{s_event.site.label}] - {#{s_event.site.x}, #{s_event.site.y}}"
  end
end