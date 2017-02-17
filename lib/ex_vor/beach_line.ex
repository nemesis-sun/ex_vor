defmodule ExVor.BeachLine do
  defstruct root: nil
  use ExVor.Logger
  alias ExVor.Event.{SiteEvent, CircleEvent}
  alias ExVor.BeachLine.{Node, Arc, BreakPoint}
  alias ExVor.Geo.{Parabola, Point, Circle, HLine}
  alias __MODULE__ # this makes %ExVor.BeachLine{} available as %BeachLine{}

  def new do
    %BeachLine{}
  end

  def handle_site_event(%BeachLine{root: nil} = beach_line,
                        %SiteEvent{site: site}) do
    arc = Arc.new(site)
    root = Node.new(arc)
    { %{beach_line | root: root},
      {nil, nil} }
  end

  def handle_site_event(%BeachLine{root: root} = beach_line,
                        %SiteEvent{site: site} = site_event) do
    {covering_arc_node, reversed_path_from_root} = find_covering_arc_node(root, [], site)
    {prev_arc_node, next_arc_node} = find_neighbour_arcs(root, reversed_path_from_root)

    new_beach_line = break_arc_node(beach_line, Enum.reverse(reversed_path_from_root), covering_arc_node, site)

    cc_events = update_circle_events_on_arc_break(site, covering_arc_node, prev_arc_node, next_arc_node)

    debug "SiteEvent updates: #{inspect(site_event)}"
    debug "New circle events:"
    debug inspect(elem(cc_events, 0))
    debug "False circle events:"
    debug inspect(elem(cc_events, 1))
    debug "----------"

    {new_beach_line, cc_events}
  end

  def handle_circle_event(%BeachLine{root: root} = beach_line,
                          %CircleEvent{sites: sites, circle: circle, footer_point: footer_point} = cc_event) do
    {left_bp_reversed_path, right_bp_reversed_path} = find_converging_breakpoints(cc_event, beach_line)
    {lower_bp_reversed_path, upper_bp_reversed_path} = if length(left_bp_reversed_path) > length(right_bp_reversed_path) do
      {left_bp_reversed_path, right_bp_reversed_path}
    else
      {right_bp_reversed_path, left_bp_reversed_path}
    end
    {prev_arc_site, reduced_arc_site, next_arc_site} = sites

    false_cc_events = false_circle_events_on_arc_reduce(beach_line, {left_bp_reversed_path, right_bp_reversed_path})

    new_beach_line = beach_line
    |> update_lower_breakpoint_node(lower_bp_reversed_path, reduced_arc_site)
    |> update_upper_breakpoint_node(upper_bp_reversed_path, prev_arc_site, next_arc_site)

    new_cc_events = new_circle_events_on_arc_reduce(new_beach_line, upper_bp_reversed_path, cc_event)

    debug "CircleEvent updates: #{inspect(cc_event)}"
    debug "New circle events:"
    debug inspect(new_cc_events)
    debug "False circle events:"
    debug inspect(false_cc_events)
    debug "----------"

    {new_beach_line, {new_cc_events, false_cc_events}}
  end

  # terminating case, leaf node aka arc encoutered
  defp find_covering_arc_node(%Node{left: nil, right: nil} = node,
                              reversed_path_from_root,
                              %Point{}) do
    {node, reversed_path_from_root}
  end

  # recursive step
  defp find_covering_arc_node(%Node{left: left, right: right, data: data} = _node,
                              reversed_path_from_root,
                              %Point{x: x, y: y} = site) do

    %BreakPoint{from_site: from_site, to_site: to_site} = data
    sweep_line = HLine.new(y)
    from_parabola = Parabola.new(from_site, sweep_line)
    to_parabola = Parabola.new(to_site, sweep_line)
    {:ok, first_break_point, second_break_point} = ExVor.Geo.Helper.parabola_intersection(from_parabola, to_parabola)

    cond do
      x < first_break_point.x -> find_covering_arc_node(left, [:left | reversed_path_from_root], site)
      x > second_break_point.x -> find_covering_arc_node(right, [:right | reversed_path_from_root], site)
      true ->
        [from_y_val, to_y_val] = [from_parabola, to_parabola] |> Enum.map(fn(p) ->
          Parabola.y_value(p, x)
        end)

        cond do
          from_y_val > to_y_val -> find_covering_arc_node(right, [:right | reversed_path_from_root], site)
          true -> find_covering_arc_node(left, [:left | reversed_path_from_root], site)
        end
    end

  end

  defp break_arc_node(%BeachLine{root: root} = beach_line,
                      path_from_root,
                      %Node{data: covering_arc} = _node,
                      %Point{} = new_site) do
    # prepare node data
    %Arc{site: covering_site} = covering_arc
    first_break_point = BreakPoint.new(covering_site, new_site)
    second_break_point = BreakPoint.new(new_site, covering_site)
    new_arc = Arc.new(new_site)

    # create and bootstrap nodes
    covering_arc_node_start = Node.new(covering_arc)
    new_arc_node = Node.new(new_arc)
    covering_arc_node_end = Node.new(covering_arc)
    second_break_point_node = Node.new(second_break_point, new_arc_node, covering_arc_node_end)
    first_break_point_node = Node.new(first_break_point, covering_arc_node_start, second_break_point_node)

    # update beach line tree by replacing node with new one
    new_root = case path_from_root do
      [] -> first_break_point_node
      _ -> put_in(root, path_from_root, first_break_point_node)
    end
    %{beach_line | root: new_root}
  end

  defp find_neighbour_arcs(_root, [] = _reversed_path_from_root) do
    {nil, nil}
  end

  defp find_neighbour_arcs(root, [leaf_node_side | reversed_parent_path_from_root ] = reversed_path_from_root) do
    # debug inspect(root)
    # debug inspect(reversed_path_from_root)
    parent_node = if reversed_parent_path_from_root == [], do: root, else: get_in(root, Enum.reverse(reversed_parent_path_from_root))

    case leaf_node_side do
      :left ->
        {next_arc_node, _} = Node.get_leftmost_child(parent_node.right)

        prev_arc_node_mutual_parent_reversed_path = Enum.drop_while(reversed_parent_path_from_root, fn(dir) -> dir == :left end)
        prev_arc_node_mutual_parent = case prev_arc_node_mutual_parent_reversed_path do
          [] -> nil
          [:right] -> root
          [_|path] -> get_in(root, Enum.reverse(path))
        end
        prev_arc_node = case prev_arc_node_mutual_parent do
          nil -> nil
          node ->
            {arc_node, _path} = Node.get_rightmost_child(node.left)
            arc_node
        end

        {prev_arc_node, next_arc_node}
      :right ->
        {prev_arc_node, _} = Node.get_rightmost_child(parent_node.left)

        next_arc_node_mutual_parent_reversed_path = Enum.drop_while(reversed_parent_path_from_root, fn(dir) -> dir == :right end)
        next_arc_node_mutual_parent = case next_arc_node_mutual_parent_reversed_path do
          [] -> nil
          [:left] -> root
          [_|path] -> get_in(root, Enum.reverse(path))
        end
        next_arc_node = case next_arc_node_mutual_parent do
          nil -> nil
          node ->
            {arc_node, _path} = Node.get_leftmost_child(node.right)
            arc_node
        end

        {prev_arc_node, next_arc_node}
    end
  end

  defp update_circle_events_on_arc_break(_, _, nil, nil) do
    {nil, nil}
  end

  defp update_circle_events_on_arc_break(%Point{} = site,
                                        %Node{data: covering_arc} = _covering_arc_node,
                                        %Node{data: prev_arc} = _prev_arc_node,
                                        nil) do
    case CircleEvent.new({prev_arc.site, covering_arc.site, site}) do
      {:error, _} -> {nil, nil}
      {:ok, event} -> if valid_circle_event?(event, site), do: {[event], nil}, else: {nil, nil}
    end
  end

  defp update_circle_events_on_arc_break(%Point{} = site,
                                        %Node{data: covering_arc} = _covering_arc_node,
                                        nil,
                                        %Node{data: next_arc} = _next_arc_node) do
    case CircleEvent.new({site, covering_arc.site, next_arc.site}) do
      {:error, _} -> {nil, nil}
      {:ok, event} -> if valid_circle_event?(event, site), do: {[event], nil}, else: {nil, nil}
    end
  end

  defp update_circle_events_on_arc_break(%Point{} = site,
                                        %Node{data: covering_arc} = _covering_arc_node,
                                        %Node{data: prev_arc} = _prev_arc_node,
                                        %Node{data: next_arc} = _next_arc_node) do
    site_triplets = case prev_arc.site.label == next_arc.site.label do
      true -> [resolve_circle_triplet_order(site, covering_arc.site, prev_arc.site)]
      false -> [{prev_arc.site, covering_arc.site, site}, {site, covering_arc.site, next_arc.site}]
    end

    new_circle_events = site_triplets
    |> Enum.map(fn(sites) ->
      case CircleEvent.new(sites) do
        {:error, _} -> nil
        {:ok, event} -> event
      end
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.filter(&(valid_circle_event?(&1, site)))

    false_circle_event = case CircleEvent.new({prev_arc.site, covering_arc.site, next_arc.site}) do
      {:error, _} -> nil
      {:ok, event} -> [event]
    end

    {new_circle_events, false_circle_event}
  end

  defp valid_circle_event?(%CircleEvent{footer_point: {_ev_x, ev_y}}, %Point{y: y}) do
    ev_y < y
  end

  defp resolve_circle_triplet_order(new_arc_site, covering_arc_site, covering_covering_arc_site) do
    case CircleEvent.new({new_arc_site, covering_arc_site, covering_covering_arc_site}) do
      {:error, _} -> {new_arc_site, covering_arc_site, covering_covering_arc_site} # doesn't matter, consequentially no circle event
      {:ok, %CircleEvent{circle: %Circle{cx: cx, cy: _cy}}} ->
        case cx > new_arc_site.x do
          true -> {new_arc_site, covering_arc_site, covering_covering_arc_site}
          false -> {covering_covering_arc_site, covering_arc_site, new_arc_site}
        end
    end
  end

  defp find_converging_breakpoints(%CircleEvent{sites: {prev_arc_site, reduced_arc_site, next_arc_site}} = cc_event,
                                  %BeachLine{root: root} = _beach_line) do
    left_breakpoint = BreakPoint.new(prev_arc_site, reduced_arc_site)
    right_breakpoint = BreakPoint.new(reduced_arc_site, next_arc_site)
    left_bp_reversed_path = find_breakpoint_path(left_breakpoint, cc_event, root, [])
    right_bp_reversed_path = find_breakpoint_path(right_breakpoint, cc_event, root, [])
    {left_bp_reversed_path, right_bp_reversed_path}
  end

  defp find_breakpoint_path(%BreakPoint{} = target_bp,
                            %CircleEvent{} = cc_event,
                            %Node{} = current_node,
                            current_path) do
    %Node{data: %BreakPoint{} = bp} = current_node
    if BreakPoint.equal?(target_bp, bp) do
      current_path
    else
      %CircleEvent{footer_point: {_fx, fy}, sites: {prev_site, _reduced_site, next_site}, circle: cc} = cc_event
      sweep_line_position = if prev_site.y > next_site.y, do: (next_site.y+fy)/2, else: (prev_site.y+fy)/2
      target_bp_coordinates = breakpoint_coordinates(target_bp, sweep_line_position)
      bp_coordinates = breakpoint_coordinates(bp, sweep_line_position)
      if target_bp_coordinates.x > bp_coordinates.x do
        find_breakpoint_path(target_bp, cc_event, current_node.right, [:right | current_path])
      else
        find_breakpoint_path(target_bp, cc_event, current_node.left, [:left | current_path])
      end
    end
  end

  defp breakpoint_coordinates(%BreakPoint{} = bp, sweep_line_position) do
    %BreakPoint{from_site: from_site, to_site: to_site} = bp
    sweep_line = HLine.new(sweep_line_position)
    from_site_para = Parabola.new(from_site, sweep_line)
    to_site_para = Parabola.new(to_site, sweep_line)
    {:ok, first_intersection, second_intersection} = ExVor.Geo.Helper.parabola_intersection(from_site_para, to_site_para)
    if from_site.y > to_site.y, do: first_intersection, else: second_intersection
  end

  defp update_lower_breakpoint_node(%BeachLine{root: root} = beach_line, reversed_bp_path, reduced_arc_site) do
    [bp_node_path|reversed_parent_path] = reversed_bp_path
    parent_path = Enum.reverse(reversed_parent_path)
    parent_node = if parent_path == [], do: root, else: get_in(root, parent_path)
    bp_node = parent_node[bp_node_path]
    %BreakPoint{from_site: from_site, to_site: to_site} = bp_node.data
    non_reduced_bp_child_node = if from_site.label == reduced_arc_site.label, do: bp_node.right, else: bp_node.left
    parent_node = put_in(parent_node, [bp_node_path], non_reduced_bp_child_node)
    new_root = if parent_path == [], do: parent_node, else: put_in(root, parent_path, parent_node)
    %{beach_line | root: new_root}
  end

  defp update_upper_breakpoint_node(%BeachLine{root: root} = beach_line, reversed_bp_path, prev_arc_site, next_arc_site) do
    bp_path = Enum.reverse(reversed_bp_path)
    bp_node = if bp_path == [], do: root, else: get_in(root, bp_path)
    new_bp = BreakPoint.new(prev_arc_site, next_arc_site)
    new_bp_node = Node.new(new_bp, bp_node.left, bp_node.right)
    new_root = if bp_path == [], do: new_bp_node, else: put_in(root, bp_path, new_bp_node)
    %{beach_line | root: new_root}
  end

  defp new_circle_events_on_arc_reduce(%BeachLine{root: root} = beach_line,
                                          reversed_bp_path,
                                          %CircleEvent{footer_point: {fx, fy}}) do
    {from_arc, to_arc} = find_connecting_arcs(beach_line, reversed_bp_path)
    [from_arc, to_arc]
    |> Enum.map(fn({%Node{} = arc_node, reversed_path}) ->
      case find_neighbour_arcs(root, reversed_path) do
        {nil, nil} -> nil
        {nil, _} -> nil
        {_, nil} -> nil
        {prev_arc_node, next_arc_node} ->
          %Node{data: %Arc{site: prev_arc_site}} = prev_arc_node
          %Node{data: %Arc{site: next_arc_site}} = next_arc_node
          %Node{data: %Arc{site: arc_site}} = arc_node
          case CircleEvent.new({prev_arc_site, arc_site, next_arc_site}) do
            {:ok, circle_event} -> if valid_circle_event?(circle_event, Point.new(fx, fy)), do: circle_event, else: nil
            {:error, _} -> nil
          end
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp find_connecting_arcs(%BeachLine{root: root} = beach_line, reversed_bp_path) do
    bp_path = Enum.reverse(reversed_bp_path)
    bp_node = if bp_path == [], do: root, else: get_in(root, bp_path)
    {from_arc_node, from_arc_reversed_path} = Node.get_rightmost_child(bp_node.left)
    {to_arc_node, to_arc_reversed_path} = Node.get_leftmost_child(bp_node.right)
    {{from_arc_node, from_arc_reversed_path ++ [:left] ++ reversed_bp_path}, {to_arc_node, to_arc_reversed_path ++ [:right] ++ reversed_bp_path}}
  end

  defp false_circle_events_on_arc_reduce(%BeachLine{root: root} = beach_line, {left_bp_reversed_path, right_bp_reversed_path}) do
    {{_, left_bp_from_arc_rev_path}, {_, _}} = find_connecting_arcs(beach_line, left_bp_reversed_path)
    {{_, _}, {_, right_bp_to_arc_rev_path}} = find_connecting_arcs(beach_line, right_bp_reversed_path)
    [left_bp_from_arc_rev_path, right_bp_to_arc_rev_path]
    |> Enum.map(fn(arc_rev_path) ->
      case find_neighbour_arcs(root, arc_rev_path) do
        {nil, nil} -> nil
        {nil, _} -> nil
        {_, nil} -> nil
        {prev_arc_node, next_arc_node} ->
          %Node{data: %Arc{site: prev_arc_site}} = prev_arc_node
          %Node{data: %Arc{site: next_arc_site}} = next_arc_node
          %Node{data: %Arc{site: arc_site}} = get_in(root, Enum.reverse(arc_rev_path))
          case CircleEvent.new({prev_arc_site, arc_site, next_arc_site}) do
            {:ok, %CircleEvent{} = cc_event} -> cc_event
            {:error, _} -> nil
          end
      end
    end)
    |> Enum.reject(&is_nil/1)
  end
end