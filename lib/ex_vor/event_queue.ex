defmodule ExVor.EventQueue do 
  defstruct q: HeapQueue.new

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

  def pop(%ExVor.EventQueue{q: q} = event_queue) do
    case HeapQueue.pop(q) do
      {{:value, _, event}, newq} -> {:ok, %{event_queue|q: newq}, event}
      {:empty, _} -> {:error, q}
    end
  end

  def empty?(%ExVor.EventQueue{q: q}) do
    HeapQueue.empty?(q)
  end

  defp site_event_priority(%ExVor.Event.SiteEvent{x: x, y: y}) do
    {-y, x}
  end

  defp circle_event_priority(%ExVor.Event.CircleEvent{footer_point: {x, y}}) do
    {-y, x}
  end
end