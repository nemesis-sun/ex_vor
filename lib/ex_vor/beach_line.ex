defmodule ExVor.BeachLine do
  defstruct root: nil

  def new do
    %ExVor.BeachLine{}
  end

  def handle_site_event(%ExVor.BeachLine{root: nil} = beach_line, 
                        %ExVor.Event.SiteEvent{site: site}) do
    arc = ExVor.BeachLine.Arc.new(site)
    root = ExVor.BeachLine.Node.new(arc)
    { %{beach_line | root: root},
      nil }
  end

  def handle_site_event(%ExVor.BeachLine{root: root} = beach_line, 
                        %ExVor.Event.SiteEvent{site: site}) do
    {node, reversed_path_from_root} = find_covering_arc_node(root, [], site)
    {prev_arc_node, next_arc_node} = find_neighbour_arcs(root, reversed_path_from_root)
    updated_tree = break_arc_node(root, Enum.reverse(reversed_path_from_root), node, site)
    cc_events = update_circle_events_on_arc_break(site, node, prev_arc_node, next_arc_node)
    { %{beach_line | root: updated_tree},
      cc_events }
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

  defp find_neighbour_arcs(_root, [] = _reversed_path_from_root) do
    {nil, nil}
  end

  defp find_neighbour_arcs(root, [leaf_node_side | reversed_parent_path_from_root ] = _reversed_path_from_root) do
    
    parent_node = if reversed_parent_path_from_root == [], do: root, else: get_in(root, Enum.reverse(reversed_parent_path_from_root))

    case leaf_node_side do
      :left ->
        next_arc_node = ExVor.BeachLine.Node.get_leftmost_child(parent_node.right)

        prev_arc_node_mutual_parent_reversed_path = Enum.drop_while(reversed_parent_path_from_root, fn(dir) -> dir == :left end)
        prev_arc_node_mutual_parent = case prev_arc_node_mutual_parent_reversed_path do
          [] -> nil
          [:right] -> root
          path -> 
            [_|path] = path
            get_in(root, Enum.reverse(path))
        end
        prev_arc_node = case prev_arc_node_mutual_parent do
          nil -> nil
          node -> ExVor.BeachLine.Node.get_rightmost_child(node.left)
        end
        
        {prev_arc_node, next_arc_node}
      :right ->
        prev_arc_node = ExVor.BeachLine.Node.get_rightmost_child(parent_node.left)

        next_arc_node_mutual_parent_reversed_path = Enum.drop_while(reversed_parent_path_from_root, fn(dir) -> dir == :right end)
        next_arc_node_mutual_parent = case next_arc_node_mutual_parent_reversed_path do
          [] -> nil
          [:left] -> root
          path -> 
            [_|path] = path
            get_in(root, Enum.reverse(path))
        end
        next_arc_node = case next_arc_node_mutual_parent do
          nil -> nil
          node -> ExVor.BeachLine.Node.get_leftmost_child(node.right)
        end
        
        {prev_arc_node, next_arc_node}
    end 
  end

  defp update_circle_events_on_arc_break(_, _, nil, nil) do
    {nil, nil}
  end

  defp update_circle_events_on_arc_break(%ExVor.Geo.Point{} = site,
                                        %ExVor.BeachLine.Node{data: covering_arc} = _covering_arc_node,
                                        %ExVor.BeachLine.Node{data: prev_arc} = _prev_arc_node,
                                        nil) do
    case ExVor.Event.CircleEvent.new({prev_arc.site, covering_arc.site, site}) do
      {:error, _} -> {nil, nil}
      {:ok, event} -> {[event], nil}
    end
  end

  defp update_circle_events_on_arc_break(%ExVor.Geo.Point{} = site,
                                        %ExVor.BeachLine.Node{data: covering_arc} = _covering_arc_node,
                                        nil, 
                                        %ExVor.BeachLine.Node{data: next_arc} = _next_arc_node) do
    case ExVor.Event.CircleEvent.new({site, covering_arc.site, next_arc.site}) do
      {:error, _} -> {nil, nil}
      {:ok, event} -> {[event], nil}
    end
  end

  defp update_circle_events_on_arc_break(%ExVor.Geo.Point{} = site,
                                        %ExVor.BeachLine.Node{data: covering_arc} = _covering_arc_node,
                                        %ExVor.BeachLine.Node{data: prev_arc} = _prev_arc_node,
                                        %ExVor.BeachLine.Node{data: next_arc} = _next_arc_node) do
    site_triplets = [{prev_arc.site, covering_arc.site, site}, {site, covering_arc.site, next_arc.site}]
    circle_events = site_triplets
    |> Enum.map(fn(sites) ->
      case ExVor.Event.CircleEvent.new(sites) do
        {:error, _} -> nil
        {:ok, event} -> event
      end
    end)
    |> Enum.reject(fn(e)->
      is_nil(e)
    end)
    removed_circle_event = case ExVor.Event.CircleEvent.new({prev_arc.site, covering_arc.site, next_arc.site}) do
      {:error, _} -> nil
      {:ok, event} -> event
    end

    {circle_events, removed_circle_event}
  end
end