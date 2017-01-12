defmodule ExVor.Geo.Helper do

  def parabola_intersection(
    %ExVor.Geo.Parabola{a: a1, b: b1, c: c1}, 
    %ExVor.Geo.Parabola{a: a2, b: b2, c: c2}) do

    a = a1-a2
    b = b1-b2
    c = c1-c2
    intersection_check = :math.pow(b,2)-4*a*c

    cond do
      intersection_check > 0 ->
        x1 = (-b+:math.sqrt(intersection_check))/(2*a)
        y1 = a1*:math.pow(x1,2) + b1*x1 + c1
        x2 = (-b-:math.sqrt(intersection_check))/(2*a)
        y2 = a1*:math.pow(x2,2) + b1*x2 + c1
        cond do
          x1>x2 -> {:ok, {%ExVor.Geo.Point{x: x2,y: y2}, %ExVor.Geo.Point{x: x1,y: y1}}}
          true -> {:ok, {%ExVor.Geo.Point{x: x1,y: y1}, %ExVor.Geo.Point{x: x2,y: y2}}}
        end
      intersection_check == 0 ->
        x = -b/(2*a)
        y = a1*:math.pow(x,2) + b1*x + c1
        {:ok, %ExVor.Geo.Point{x: x,y: y}}
      true -> {:error, :no_intersection}
    end
  end
end