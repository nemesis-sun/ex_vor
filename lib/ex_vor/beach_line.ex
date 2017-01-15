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
    {node, reversed_path_from_root} = find_covering_arc_node(root, [], site)
    updated_tree = break_arc_node(root, Enum.reverse(reversed_path_from_root), node, site)
    %{beach_line | root: updated_tree}
  end

  # terminating case, leaf node aka arc encoutered
  defp find_covering_arc_node(%ExVor.BeachLine.Node{left: nil, right: nil} = node,
                              reversed_path_from_root,
                              %ExVor.Geo.Point{}) do
    {node, reversed_path_from_root}
  end

  # recursive step
  defp find_covering_arc_node(%ExVor.BeachLine.Node{left: left, right: right, data: data} = _node,
                              reversed_path_from_root,
                              %ExVor.Geo.Point{x: x, y: y} = site) do

    %ExVor.BeachLine.BreakPoint{from_site: from_site, to_site: to_site} = data
    sweep_line = ExVor.Geo.HLine.new(y)
    from_parabola = ExVor.Geo.Parabola.new(from_site, sweep_line)
    to_parabola = ExVor.Geo.Parabola.new(to_site, sweep_line)
    {:ok, first_break_point, second_break_point} = ExVor.Geo.Helper.parabola_intersection(from_parabola, to_parabola)

    cond do
      x < first_break_point.x -> find_covering_arc_node(left, [:left | reversed_path_from_root], site)
      x > second_break_point.x -> find_covering_arc_node(right, [:right | reversed_path_from_root], site)
      true -> 
        [from_y_val, to_y_val] = [from_parabola, to_parabola] |> Enum.map(fn(p) -> 
          ExVor.Geo.Parabola.y_value(p, x) 
        end)

        cond do
          from_y_val > to_y_val -> find_covering_arc_node(right, [:right | reversed_path_from_root], site)
          true -> find_covering_arc_node(left, [:left | reversed_path_from_root], site)
        end
    end
    
  end

  defp break_arc_node(root, path_from_root, 
                      %ExVor.BeachLine.Node{data: covering_arc} = _node,
                      %ExVor.Geo.Point{} = new_site) do
    # prepare node data
    %ExVor.BeachLine.Arc{site: covering_site} = covering_arc
    first_break_point = ExVor.BeachLine.BreakPoint.new(covering_site, new_site)
    second_break_point = ExVor.BeachLine.BreakPoint.new(new_site, covering_site)
    new_arc = ExVor.BeachLine.Arc.new(new_site)

    # create and bootstrap nodes
    covering_arc_node_start = ExVor.BeachLine.Node.new(covering_arc)
    new_arc_node = ExVor.BeachLine.Node.new(new_arc)
    covering_arc_node_end = ExVor.BeachLine.Node.new(covering_arc)
    second_break_point_node = ExVor.BeachLine.Node.new(second_break_point, new_arc_node, covering_arc_node_end)
    first_break_point_node = ExVor.BeachLine.Node.new(first_break_point, covering_arc_node_start, second_break_point_node)

    # update beach line tree by replacing node with new one
    case path_from_root do
      [] -> first_break_point_node
      _ -> put_in(root, path_from_root, first_break_point_node)
    end
  end
end