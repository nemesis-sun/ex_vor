defmodule ExVor.CircleEvent do
  defstruct cx: nil, cy: nil, sites: nil, footer_point: nil

  def new({ %ExVor.Site{},
            %ExVor.Site{},
            %ExVor.Site{} } = sites) do
    if valid_sites?(sites), do: {:ok, new_circle_event(sites)},else: {:error, :invalid_sites}
  end

  defp valid_sites?({s1, s2, s3}) do
    cond do
      s1.x == s2.x && s2.x== s3.x -> false # collinear, verticle line => invalid
      (s1.y - s2.y)/(s1.x - s2.x) == (s1.y - s3.y)/(s1.x - s3.x) -> false # collinear, other cases => invalid
      true -> true # otherwise, valid
    end
  end

  defp new_circle_event({s1, s2, s3} = sites) do
    # solving for center C(cx, cy) and radius r
    # (s1.x - cx)^2 + (s1.y - cy)^2 = 
    # (s2.x - cx)^2 + (s2.y - cy)^2 =
    # (s3.x - cx)^2 + (s3.y - cy)^2 = r^2

    # a = -2*s1.x + 2*s2.x, b = -2*s1.y + 2*s2.y, c = s1.x^2 + s1.y^2 - s2.x^2 - s2.y^2
    # d = -2*s2.x + 2*s3.x, e = -2*s2.y + 2*s3.y, f = s2.x^2 + s2.y^2 - s3.x^2 - s3.y^2
    # a*cx + b*cy + c = 0
    # d*cx + e*cy + f = 0

    # a and d must not be both zero, assume a is not zero

    # d*cx + (b*d/a)*cy + c*d/a = 0
    # d*cx + e*cy + f = 0

    # cy = (c*d/a-f)/(e-b*d/a)
    # cx = (-c - b*cy)/a

    a = -2*s1.x + 2*s2.x
    b = -2*s1.y + 2*s2.y
    c = square(s1.x) + square(s1.y) - square(s2.x) - square(s2.y)
    d = -2*s2.x + 2*s3.x
    e = -2*s2.y + 2*s3.y
    f = square(s2.x) + square(s2.y) - square(s3.x) - square(s3.y)


    {cy, cx} = cond do
      a != 0 -> 
        t = (c*d/a-f)/(e-b*d/a)
        {t, (-c-b*t)/a}
      true -> 
        t = -c/b
        {t, (-f-e*t)/d}
    end
    r = (square(s1.x-cx) + square(s1.y-cy)) |> :math.pow(0.5)

    %ExVor.CircleEvent{cx: cx, cy: cy, sites: sites, footer_point: {cx, cy-r}}

  end

  defp square(f) do
    :math.pow(f,2)
  end
end