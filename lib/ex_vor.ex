defmodule ExVor do
  alias ExVor.{BeachLine, EventQueue}
  alias ExVor.Event.{SiteEvent, CircleEvent}
  defstruct beach_line: BeachLine.new, event_queue: EventQueue.new
  use ExVor.Logger

  def new do
    %ExVor{}
  end

  def input_sites(%ExVor{} = ex_vor, sites) do
    input_sites(ex_vor, sites, 1)
  end

  def input_sites(%ExVor{}=ex_vor, [] = _sites, _next_label) do
    ex_vor
  end

  def input_sites(%ExVor{event_queue: event_queue} = ex_vor, [%ExVor.Geo.Point{} = p | t] = _sites, next_label) do
    site_with_label = %{p|label: next_label}
    new_event_queue = EventQueue.push(event_queue, SiteEvent.new(site_with_label))
    new_ex_vor = %{ex_vor | event_queue: new_event_queue}
    input_sites(new_ex_vor, t, next_label+1)
  end

  def process(%ExVor{event_queue: event_queue, beach_line: beach_line} = ex_vor) do
    case EventQueue.pop(event_queue) do
      {:error, _queue} -> beach_line
      {:ok, new_queue, next_event} ->
        debug "processing next event #{inspect(next_event)}"
        {new_beach_line, cc_event_updates} = case next_event do
          %SiteEvent{} -> BeachLine.handle_site_event(beach_line, next_event)
          %CircleEvent{} -> BeachLine.handle_circle_event(beach_line, next_event)
        end
        new_queue = case cc_event_updates do
          {nil, nil} -> new_queue
          {new_events, false_event} ->
            queue_with_new_events = Enum.reduce(new_events, new_queue, &(EventQueue.push(&2, &1)))
            unless false_event == nil, do: EventQueue.remove_false_circle_event(queue_with_new_events, false_event), else: queue_with_new_events
        end
        process(%{ex_vor | event_queue: new_queue, beach_line: new_beach_line})
    end
  end
end