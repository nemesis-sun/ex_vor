defmodule ExVor.EventQueue do
  defstruct q: HeapQueue.new, false_cc_events: []

  def new do
    %ExVor.EventQueue{}
  end

  def push(%ExVor.EventQueue{q: q} = event_queue, %ExVor.Event.SiteEvent{} = site_event) do
    p = site_event_priority site_event
    %{event_queue | q: HeapQueue.push(q,p,site_event)}
  end

  def push(%ExVor.EventQueue{q: q} = event_queue, %ExVor.Event.CircleEvent{} = circle_event) do
    p = circle_event_priority circle_event
    %{event_queue | q: HeapQueue.push(q,p,circle_event)}
  end

  def pop(%ExVor.EventQueue{q: q, false_cc_events: false_cc_events} = event_queue) do
    case HeapQueue.pop(q) do
      {{:value, _, %ExVor.Event.SiteEvent{} = event}, newq} -> {:ok, %{event_queue|q: newq}, event}
      {{:value, _, %ExVor.Event.CircleEvent{} = event}, newq} ->
        cc_event_id = circle_event_id(event)
        idx = Enum.find_index(false_cc_events, &(&1==cc_event_id))
        case idx do
          nil -> {:ok, %{event_queue|q: newq}, event}
          _ -> pop(%{event_queue|q: newq, false_cc_events: List.delete_at(false_cc_events, idx)})
        end
      {:empty, _} -> {:error, q}
    end
  end

  def remove_false_circle_event(%ExVor.EventQueue{false_cc_events: false_cc_events} = event_queue, %ExVor.Event.CircleEvent{} = cc_event) do
    new_false_cc_events = [circle_event_id(cc_event) | false_cc_events]
    %{event_queue | false_cc_events: new_false_cc_events}
  end

  def empty?(%ExVor.EventQueue{q: q}) do
    HeapQueue.empty?(q)
  end

  defp site_event_priority(%ExVor.Event.SiteEvent{site: %ExVor.Geo.Point{x: x, y: y}}) do
    {-y, x}
  end

  defp circle_event_priority(%ExVor.Event.CircleEvent{footer_point: {x, y}}) do
    {-y, x}
  end

  defp circle_event_id(%ExVor.Event.CircleEvent{sites: sites}) do
    sites
    |> Tuple.to_list
    |> Enum.map(fn(%ExVor.Geo.Point{label: l})-> l end)
    |> Enum.sort
    |> Enum.join("|")
  end
end