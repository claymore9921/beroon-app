defmodule Beroon.Calendar do
  @persian_months ~w(فروردین اردیبهشت خرداد تیر مرداد شهریور مهر آبان آذر دی بهمن اسفند)

  def persian_date(%Date{} = date) do
    {year, month, day} = gregorian_to_jalali(date.year, date.month, date.day)
    "#{day} #{Enum.at(@persian_months, month - 1)} #{year}"
  end

  defp gregorian_to_jalali(gy, gm, gd) do
    g_days_in_month = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
    j_days_in_month = [31, 31, 31, 31, 31, 31, 30, 30, 30, 30, 30, 29]

    gy2 = gy - 1600
    gm2 = gm - 1
    gd2 = gd - 1

    g_day_no =
      365 * gy2 + div(gy2 + 3, 4) - div(gy2 + 99, 100) + div(gy2 + 399, 400) +
        Enum.sum(Enum.take(g_days_in_month, gm2)) + gd2 +
        if(gm2 > 1 and leap_gregorian?(gy), do: 1, else: 0)

    j_day_no = g_day_no - 79
    j_np = div(j_day_no, 12053)
    j_day_no = rem(j_day_no, 12053)

    jy = 979 + 33 * j_np + 4 * div(j_day_no, 1461)
    j_day_no = rem(j_day_no, 1461)

    {jy, j_day_no} =
      if j_day_no >= 366 do
        {jy + div(j_day_no - 1, 365), rem(j_day_no - 1, 365)}
      else
        {jy, j_day_no}
      end

    {jm, jd} = find_jalali_month(j_day_no, j_days_in_month, 1)
    {jy, jm, jd}
  end

  defp find_jalali_month(day_no, [days | rest], month) when day_no >= days do
    find_jalali_month(day_no - days, rest, month + 1)
  end

  defp find_jalali_month(day_no, _months, month), do: {month, day_no + 1}

  defp leap_gregorian?(year) do
    (rem(year, 4) == 0 and rem(year, 100) != 0) or rem(year, 400) == 0
  end
end
