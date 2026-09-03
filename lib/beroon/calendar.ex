defmodule Beroon.Calendar do
  @persian_months ~w(فروردین اردیبهشت خرداد تیر مرداد شهریور مهر آبان آذر دی بهمن اسفند)
  @tehran_offset_seconds 12_600

  def tehran_now, do: DateTime.utc_now() |> DateTime.add(@tehran_offset_seconds, :second)
  def tehran_datetime(nil), do: nil
  def tehran_datetime(%DateTime{} = datetime), do: DateTime.add(datetime, @tehran_offset_seconds, :second)
  def tehran_date(%DateTime{} = datetime), do: datetime |> tehran_datetime() |> DateTime.to_date()

  def persian_date(%Date{} = date) do
    {year, month, day} = gregorian_to_jalali(date.year, date.month, date.day)
    "#{day} #{Enum.at(@persian_months, month - 1)} #{year}"
  end

  def persian_numeric_date(%Date{} = date) do
    {year, month, day} = gregorian_to_jalali(date.year, date.month, date.day)
    :io_lib.format(~c"~4..0B/~2..0B/~2..0B", [year, month, day]) |> IO.iodata_to_binary()
  end

  def persian_datetime(nil), do: "-"

  def persian_datetime(%DateTime{} = datetime) do
    local = tehran_datetime(datetime)
    "#{persian_numeric_date(DateTime.to_date(local))} - #{Calendar.strftime(local, "%H:%M")}"
  end

  def persian_time(nil), do: "-"
  def persian_time(%DateTime{} = datetime), do: datetime |> tehran_datetime() |> Calendar.strftime("%H:%M")

  def parse_persian_date(value) when is_binary(value) do
    normalized = value |> String.trim() |> String.replace("-", "/")

    with [year, month, day] <- String.split(normalized, "/"),
         {jalali_year, ""} <- Integer.parse(year),
         {jalali_month, ""} <- Integer.parse(month),
         {jalali_day, ""} <- Integer.parse(day),
         true <- jalali_month in 1..12 and jalali_day in 1..31,
         {gregorian_year, gregorian_month, gregorian_day} <-
           jalali_to_gregorian(jalali_year, jalali_month, jalali_day),
         {:ok, date} <- Date.new(gregorian_year, gregorian_month, gregorian_day) do
      {:ok, date}
    else
      _ -> :error
    end
  end

  def parse_persian_date(_), do: :error

  defp gregorian_to_jalali(gregorian_year, gregorian_month, gregorian_day) do
    gregorian_days_in_month = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
    jalali_days_in_month = [31, 31, 31, 31, 31, 31, 30, 30, 30, 30, 30, 29]

    year = gregorian_year - 1600
    month = gregorian_month - 1
    day = gregorian_day - 1

    gregorian_day_number =
      365 * year + div(year + 3, 4) - div(year + 99, 100) + div(year + 399, 400) +
        Enum.sum(Enum.take(gregorian_days_in_month, month)) + day +
        if(month > 1 and leap_gregorian?(gregorian_year), do: 1, else: 0)

    jalali_day_number = gregorian_day_number - 79
    jalali_cycle = div(jalali_day_number, 12_053)
    jalali_day_number = rem(jalali_day_number, 12_053)

    jalali_year = 979 + 33 * jalali_cycle + 4 * div(jalali_day_number, 1461)
    jalali_day_number = rem(jalali_day_number, 1461)

    {jalali_year, jalali_day_number} =
      if jalali_day_number >= 366 do
        {jalali_year + div(jalali_day_number - 1, 365), rem(jalali_day_number - 1, 365)}
      else
        {jalali_year, jalali_day_number}
      end

    {jalali_month, jalali_day} = find_month(jalali_day_number, jalali_days_in_month, 1)
    {jalali_year, jalali_month, jalali_day}
  end

  defp jalali_to_gregorian(jalali_year, jalali_month, jalali_day) do
    jalali_days_in_month = [31, 31, 31, 31, 31, 31, 30, 30, 30, 30, 30, 29]
    year = jalali_year - 979

    jalali_day_number =
      365 * year + div(year, 33) * 8 + div(rem(year, 33) + 3, 4) +
        Enum.sum(Enum.take(jalali_days_in_month, jalali_month - 1)) + jalali_day - 1

    gregorian_day_number = jalali_day_number + 79
    gregorian_year = 1600 + 400 * div(gregorian_day_number, 146_097)
    gregorian_day_number = rem(gregorian_day_number, 146_097)

    {gregorian_year, gregorian_day_number} =
      if gregorian_day_number >= 36_525 do
        adjusted = gregorian_day_number - 1
        year = gregorian_year + 100 * div(adjusted, 36_524)
        remaining = rem(adjusted, 36_524)

        if remaining >= 365 do
          {year + 1, remaining - 365}
        else
          {year, remaining}
        end
      else
        {gregorian_year, gregorian_day_number}
      end

    gregorian_year = gregorian_year + 4 * div(gregorian_day_number, 1461)
    gregorian_day_number = rem(gregorian_day_number, 1461)

    {gregorian_year, gregorian_day_number} =
      if gregorian_day_number >= 366 do
        {gregorian_year + div(gregorian_day_number - 1, 365),
         rem(gregorian_day_number - 1, 365)}
      else
        {gregorian_year, gregorian_day_number}
      end

    gregorian_days_in_month =
      [31, if(leap_gregorian?(gregorian_year), do: 29, else: 28), 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]

    {gregorian_month, gregorian_day} = find_month(gregorian_day_number, gregorian_days_in_month, 1)
    {gregorian_year, gregorian_month, gregorian_day}
  end

  defp find_month(day_number, [days | rest], month) when day_number >= days,
    do: find_month(day_number - days, rest, month + 1)

  defp find_month(day_number, _months, month), do: {month, day_number + 1}

  defp leap_gregorian?(year) do
    (rem(year, 4) == 0 and rem(year, 100) != 0) or rem(year, 400) == 0
  end
end
