defmodule ExVor.Event.CircleEvent do
  defstruct cx: nil, cy: nil, sites: nil, footer_point: nil

  def new({ %ExVor.Geo.Point{},
            %ExVor.Geo.Point{},
            %ExVor.Geo.Point{} } = sites) do
    case ExVor.Geo.Circle.from_points(sites) do
      {:error, _} = err -> err
      {:ok, %ExVor.Geo.Circle{cx: cx, cy: cy, r: r}} -> 
        %ExVor.Event.CircleEvent{cx: cx, cy: cy, sites: sites, footer_point: {cx, cy-r}}
    end
  end

end