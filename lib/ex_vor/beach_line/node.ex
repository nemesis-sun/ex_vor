defmodule ExVor.BeachLine.Node do
  defstruct data: nil, left: nil, right: nil

  def new(data, left \\ nil, right \\ nil) do
    %ExVor.BeachLine.Node{data: data, left: left, right: right}
  end

  def is_leaf?(%ExVor.BeachLine.Node{left: l, right: r}) do
    l == nil && r == nil
  end

  @behaviour Access
  
  def fetch(%ExVor.BeachLine.Node{left: l, right: r}, key) do
    case key do
      :left -> {:ok, l}
      :right -> {:ok, r}
      _ -> :error
    end
  end

  def get(%ExVor.BeachLine.Node{} = node, key, default) do
    case fetch(node, key) do
      {:ok, value} -> value
      :error -> default
    end
  end

  def get_and_update(%ExVor.BeachLine.Node{} = node, key, cb) do
    value = fetch(node, key)
    cb_value = case value do
      {:ok, value} -> cb.(value)
      :error -> cb.(nil)
    end

    case cb_value do
      {ret, new_value} ->
        new_node = %{node | key => new_value}
        {ret, new_node}
      :pop ->
        new_node = %{node | key => nil}
        {value, new_node}
    end
  end

  def pop(%ExVor.BeachLine.Node{} = node, key) do
    case fetch(node, key) do
      {:ok, value} ->
        new_node = %{node | key => nil}
        {value, new_node}
      :error ->
        {nil, node}
    end
  end
end