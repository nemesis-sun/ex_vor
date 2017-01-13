defmodule ExVor.BeachLine do
  defstruct root: nil

  def new do
    %ExVor.BeachLine{}
  end

  def handle_site_event(%ExVor.BeachLine{root: nil} = beach_line, 
                        %ExVor.Event.SiteEvent{site: site}) do
    arc = ExVor.BeachLine.Arc.new(site)
    root = ExVor.BeachLine.Node.new(arc)
    %{beach_line | root: root}
  end

  def handle_site_event(%ExVor.BeachLine{root: root} = beach_line, 
                        %ExVor.Event.SiteEvent{site: site}) do
    {node, reversed_path_from_root} = find_covering_arc_node(root, nil, site)
    break_arc_node(root, node, Enum.reverse(reversed_path_from_root))
  end

  # terminating case, leaf node encoutered
  defp find_covering_arc_node(%ExVor.BeachLine.Node{left: nil, right: nil} = node,
                              reversed_path_from_root,
                              %ExVor.Geo.Point{}) do
    {node, reversed_path_from_root}
  end

  # recursive step
  defp find_covering_arc_node(%ExVor.BeachLine.Node{left: left, right: right, data: data} = node,
                              reversed_path_from_root,
                              %ExVor.Geo.Point{x: x, y: y} = site) do

    %ExVor.BeachLine.BreakPoint{from_site: from_site, to_site: to_site} = data
    sweep_line = ExVor.Geo.HLine.new(y)

    from_y_val = ExVor.Geo.Parabola.new(from_site, sweep_line)
    |> ExVor.Geo.Parabola.y_value(x)

    to_y_val = ExVor.Geo.Parabola.new(to_site, sweep_line)
    |> ExVor.Geo.Parabola.y_value(x)

    cond do
      from_y_val > to_y_val -> find_covering_arc_node(left, [:left | reversed_path_from_root], site)
      true -> find_covering_arc_node(right, [:right | reversed_path_from_root], site)
    end
  end

  defp break_arc_node(root, node, path_from_root) do
    
  end
end