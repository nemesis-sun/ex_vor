defmodule ExVor.EventQueue do
  defstruct q: HeapQueue.new, false_cc_events: %{}
  use ExVor.Logger
  alias ExVor.Event.{SiteEvent, CircleEvent}
  alias __MODULE__

  def new do
    %EventQueue{}
  end

  def push(%EventQueue{q: q} = event_queue, %SiteEvent{} = site_event) do
    p = site_event_priority site_event
    %{event_queue | q: HeapQueue.push(q,p,site_event)}
  end

  def push(%EventQueue{q: q} = event_queue, %CircleEvent{} = circle_event) do
    p = circle_event_priority circle_event
    %{event_queue | q: HeapQueue.push(q,p,circle_event)}
  end

  def pop(%EventQueue{q: q, false_cc_events: false_cc_events} = event_queue) do
    case HeapQueue.pop(q) do
      {{:value, _, %SiteEvent{} = event}, newq} -> {:ok, %{event_queue|q: newq}, event}
      {{:value, _, %CircleEvent{} = event}, newq} ->
        event_id = CircleEvent.id(event)
        is_false_event = false_cc_events[event_id]
        case is_false_event do
          nil -> {:ok, %{event_queue|q: newq}, event}
          _ ->
            debug "False circle event encoutered #{event_id}, ignore and process next event"
            pop(%{event_queue|q: newq, false_cc_events: Map.drop(false_cc_events, [event_id])})
        end
      {:empty, _} -> {:error, q}
    end
  end

  def remove_false_circle_event(%EventQueue{false_cc_events: false_cc_events} = event_queue, %CircleEvent{} = cc_event) do
    new_false_cc_events = Map.put(false_cc_events, CircleEvent.id(cc_event), true)
    %{event_queue | false_cc_events: new_false_cc_events}
  end

  def empty?(%EventQueue{q: q}) do
    HeapQueue.empty?(q)
  end

  defp site_event_priority(%SiteEvent{site: %ExVor.Geo.Point{x: x, y: y}}) do
    {-y, x}
  end

  defp circle_event_priority(%CircleEvent{footer_point: {x, y}}) do
    {-y, x}
  end

  def circle_event_id(%CircleEvent{sites: sites}) do
    sites
    |> Tuple.to_list
    |> Enum.map(fn(%ExVor.Geo.Point{label: l})-> l end)
    |> Enum.sort
    |> Enum.join("|")
  end
end