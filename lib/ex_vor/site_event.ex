defmodule ExVor.SiteEvent do
  defstruct x: nil, y: nil, site: nil

  def new(%ExVor.Site{} = s) do
    %ExVor.SiteEvent{x: s.x, y: s.y, site: s}
  end
end