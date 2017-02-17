defmodule ExVor.Event.CircleEvent do
  defstruct circle: nil, sites: nil, footer_point: nil

  def new({ %ExVor.Geo.Point{},
            %ExVor.Geo.Point{},
            %ExVor.Geo.Point{} } = sites) do
    case ExVor.Geo.Circle.from_points(sites) do
      {:error, _} = err -> err
      {:ok, %ExVor.Geo.Circle{cx: cx, cy: cy, r: r} = circle} -> {:ok, %ExVor.Event.CircleEvent{circle: circle, sites: sites, footer_point: {cx, cy-r}}}
    end
  end

  def id(%ExVor.Event.CircleEvent{sites: sites}) do
    sites
    |> Tuple.to_list
    |> Enum.map(&(Map.get(&1,:label)))
    |> Enum.join("|")
  end

end

defimpl String.Chars, for: ExVor.Event.CircleEvent do
  def to_string(cc_event) do
    "CircleEvent[#{ExVor.Event.CircleEvent.id(cc_event)}] - #{inspect cc_event.footer_point}"
  end
end