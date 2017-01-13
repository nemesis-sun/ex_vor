defmodule ExVor.Geo.Parabola do
  defstruct a: nil, b: nil, c: nil

  # get new parabola given focus and horizontal directrix
  def new(%ExVor.Geo.Point{x: f_x, y: f_y}, %ExVor.Geo.HLine{y: d_y}) do
    # (x - v_x)^2 = 4p(y-v_y)
    # where (v_x, v_y) is the vertex
    # p is the distance from vertex to focus/directrix

    v_x = f_x
    v_y = (f_y + d_y)/2
    p = abs(v_y-d_y)

    a = 1/(4*p)
    b = -v_x/(2*p)
    c = (:math.pow(v_x,2)+4*p*v_y)/(4*p)

    %ExVor.Geo.Parabola{a: a, b: b, c: c}
  end

  def y_value(%ExVor.Geo.Parabola{a: a, b: b, c: c}, x) do
    a*:math.pow(x,2) + b*x + c
  end 
end