defmodule ExVor.BeachLine.Node do
  defstruct data: nil, left: nil, right: nil
  alias __MODULE__

  def new(data, left \\ nil, right \\ nil) do
    %Node{data: data, left: left, right: right}
  end

  def is_leaf?(%Node{left: l, right: r}) do
    l == nil && r == nil
  end

  def get_leaf_nodes_ordered(%Node{} = node) do
    get_leaf_nodes_ordered_p(node, [])
  end

  defp get_leaf_nodes_ordered_p(%Node{left: nil, right: nil} = node, arc_node_list) do
    IO.inspect node.data
    [node | arc_node_list]
  end

  defp get_leaf_nodes_ordered_p(%Node{left: l, right: r} = _node, arc_node_list) do
    arc_node_list = get_leaf_nodes_ordered_p(r, arc_node_list)
    get_leaf_nodes_ordered_p(l, arc_node_list)
  end

  def get_leftmost_child(%Node{} = node) do
    get_leftmost_child(node, [])
  end

  def get_leftmost_child(%Node{left: nil, right: nil} = node, path) do
    {node, path}
  end

  def get_leftmost_child(%Node{left: l}, path) do
    get_leftmost_child(l, [:left | path])
  end

  def get_rightmost_child(%Node{} = node) do
    get_rightmost_child(node, [])
  end

  def get_rightmost_child(%Node{left: nil, right: nil} = node, path) do
    {node, path}
  end

  def get_rightmost_child(%Node{right: r}, path) do
    get_rightmost_child(r, [:right | path])
  end

  @behaviour Access

  def fetch(%Node{left: l, right: r}, key) do
    case key do
      :left -> {:ok, l}
      :right -> {:ok, r}
      _ -> :error
    end
  end

  def get(%Node{} = node, key, default) do
    case fetch(node, key) do
      {:ok, value} -> value
      :error -> default
    end
  end

  def get_and_update(%Node{} = node, key, cb) do
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

  def pop(%Node{} = node, key) do
    case fetch(node, key) do
      {:ok, value} ->
        new_node = %{node | key => nil}
        {value, new_node}
      :error ->
        {nil, node}
    end
  end
end