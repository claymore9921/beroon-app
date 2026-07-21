defmodule Beroon.XlsxReader do
  @moduledoc false

  @required_headers ~w(plate qrscan branch devicetype)

  def read(path) do
    with {:ok, files} <- :zip.extract(String.to_charlist(path), [:memory]),
         file_map <- Map.new(files, fn {name, body} -> {List.to_string(name), body} end),
         {:ok, sheet_xml} <- first_sheet(file_map),
         shared_strings <- shared_strings(file_map),
         {:ok, rows} <- parse_rows(sheet_xml, shared_strings),
         {:ok, records} <- rows_to_records(rows) do
      {:ok, records}
    else
      {:error, reason} -> {:error, reason}
      _ -> {:error, "فایل اکسل قابل خواندن نیست."}
    end
  rescue
    _ -> {:error, "فایل اکسل معتبر نیست یا ساختار آن پشتیبانی نمی‌شود."}
  end

  defp first_sheet(files) do
    case Enum.find(files, fn {name, _} -> String.match?(name, ~r|^xl/worksheets/sheet\d+\.xml$|) end) do
      nil -> {:error, "هیچ Sheet قابل خواندنی در فایل پیدا نشد."}
      {_name, xml} -> {:ok, xml}
    end
  end

  defp shared_strings(files) do
    case Map.get(files, "xl/sharedStrings.xml") do
      nil -> []
      xml ->
        Regex.scan(~r/<si\b[^>]*>(.*?)<\/si>/s, xml, capture: :all_but_first)
        |> Enum.map(fn [item] ->
          Regex.scan(~r/<t\b[^>]*>(.*?)<\/t>/s, item, capture: :all_but_first)
          |> Enum.map_join("", fn [text] -> decode_xml(text) end)
        end)
    end
  end

  defp parse_rows(xml, shared_strings) do
    rows =
      Regex.scan(~r/<row\b[^>]*>(.*?)<\/row>/s, xml, capture: :all_but_first)
      |> Enum.map(fn [row_xml] -> parse_cells(row_xml, shared_strings) end)

    {:ok, rows}
  end

  defp parse_cells(row_xml, shared_strings) do
    Regex.scan(~r/<c\b([^>]*)>(.*?)<\/c>/s, row_xml, capture: :all_but_first)
    |> Enum.reduce(%{}, fn [attrs, content], acc ->
      ref = capture(attrs, ~r/\br="([A-Z]+)\d+"/)
      type = capture(attrs, ~r/\bt="([^"]+)"/)
      value = cell_value(content, type, shared_strings)

      if ref, do: Map.put(acc, ref, value), else: acc
    end)
  end

  defp cell_value(content, "s", shared_strings) do
    case capture(content, ~r/<v>(.*?)<\/v>/s) do
      nil -> ""
      index -> Enum.at(shared_strings, parse_integer(index), "")
    end
  end

  defp cell_value(content, "inlineStr", _shared_strings) do
    Regex.scan(~r/<t\b[^>]*>(.*?)<\/t>/s, content, capture: :all_but_first)
    |> Enum.map_join("", fn [text] -> decode_xml(text) end)
  end

  defp cell_value(content, _type, _shared_strings) do
    content
    |> capture(~r/<v>(.*?)<\/v>/s)
    |> to_string()
    |> decode_xml()
  end

  defp rows_to_records([]), do: {:error, "فایل اکسل خالی است."}

  defp rows_to_records([header_row | data_rows]) do
    headers =
      header_row
      |> Enum.map(fn {column, value} -> {column, normalize_header(value)} end)
      |> Map.new()

    missing = @required_headers -- Map.values(headers)

    if missing != [] do
      {:error, "ستون‌های الزامی پیدا نشد: #{Enum.join(missing, ", ")}"}
    else
      records =
        data_rows
        |> Enum.with_index(2)
        |> Enum.map(fn {row, row_number} ->
          values =
            headers
            |> Enum.map(fn {column, header} -> {header, row |> Map.get(column, "") |> clean()} end)
            |> Map.new()

          Map.put(values, "row_number", row_number)
        end)
        |> Enum.reject(fn row ->
          Enum.all?(@required_headers, &(Map.get(row, &1, "") == ""))
        end)

      {:ok, records}
    end
  end

  defp normalize_header(value) do
    value
    |> clean()
    |> String.downcase()
    |> String.replace(~r/[\s_-]+/u, "")
    |> case do
      "plate" -> "plate"
      "پلاک" -> "plate"
      "qrscan" -> "qrscan"
      "qr" -> "qrscan"
      "barcode" -> "qrscan"
      "بارکد" -> "qrscan"
      "branch" -> "branch"
      "شعبه" -> "branch"
      "devicetype" -> "devicetype"
      "device" -> "devicetype"
      "model" -> "devicetype"
      "مدلدستگاه" -> "devicetype"
      "مدل" -> "devicetype"
      other -> other
    end
  end

  defp capture(value, regex) do
    case Regex.run(regex, value, capture: :all_but_first) do
      [match | _] -> match
      _ -> nil
    end
  end

  defp parse_integer(value) do
    case Integer.parse(value) do
      {integer, _} -> integer
      _ -> -1
    end
  end

  defp clean(value), do: value |> to_string() |> String.trim()

  defp decode_xml(value) do
    value =
      value
      |> to_string()
      |> String.replace("&amp;", "&")
      |> String.replace("&lt;", "<")
      |> String.replace("&gt;", ">")
      |> String.replace("&quot;", "\"")
      |> String.replace("&apos;", "'")

    Regex.replace(~r/&#(\d+);/, value, fn _, number ->
      case Integer.parse(number) do
        {codepoint, ""} when codepoint >= 0 and codepoint <= 0x10FFFF ->
          <<codepoint::utf8>>

        _ ->
          ""
      end
    end)
  end
end
