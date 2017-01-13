defmodule ExVor.BeachLine.Node do
  defstruct data: nil, left: nil, right: nil

  def new(data, left \\ nil, right \\ nil) do
    %ExVor.BeachLine.Node{data: data, left: left, right: right}
  end

  def is_leaf?(%ExVor.BeachLine.Node{left: l, right: r}) do
    l == nil && r == nil
  end
end