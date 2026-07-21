defmodule BeroonWeb.ScooterController do
  use BeroonWeb, :controller

  alias Beroon.Fleet
  alias Beroon.Fleet.Scooter
  alias Beroon.Operations
  alias Beroon.XlsxReader

  def index(conn, params) do
    query = params |> Map.get("q", "") |> String.trim()

    render(conn, :index,
      scooters: Fleet.list_scooters_with_details(query),
      query: query
    )
  end

  def new(conn, _params) do
    changeset = Fleet.change_scooter(%Scooter{})

    render(conn, :new,
      form: Phoenix.Component.to_form(changeset),
      branches: Operations.list_branches(),
      device_types: Fleet.list_device_types()
    )
  end

  def create(conn, %{"scooter" => scooter_params}) do
    case Fleet.create_scooter(scooter_params) do
      {:ok, scooter} ->
        conn
        |> put_flash(:info, "دستگاه ثبت شد.")
        |> redirect(to: ~p"/scooters/#{scooter}")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :new,
          form: Phoenix.Component.to_form(changeset),
          branches: Operations.list_branches(),
          device_types: Fleet.list_device_types()
        )
    end
  end


  def import(conn, %{"excel_file" => %Plug.Upload{path: path, filename: filename}}) do
    if String.downcase(Path.extname(filename)) != ".xlsx" do
      conn
      |> put_flash(:error, "فقط فایل Excel با پسوند .xlsx قابل قبول است.")
      |> redirect(to: ~p"/scooters")
    else
      case XlsxReader.read(path) do
        {:ok, rows} ->
          result = import_rows(rows)

          message = "#{result.created} دستگاه با موفقیت وارد شد."
          error_message = summarize_import_errors(result.errors)

          conn
          |> put_flash(:info, message)
          |> maybe_put_import_error(error_message)
          |> redirect(to: ~p"/scooters")

        {:error, reason} ->
          conn
          |> put_flash(:error, reason)
          |> redirect(to: ~p"/scooters")
      end
    end
  end

  def import(conn, _params) do
    conn
    |> put_flash(:error, "ابتدا فایل Excel را انتخاب کنید.")
    |> redirect(to: ~p"/scooters")
  end

  defp import_rows(rows) do
    branches = Operations.list_branches()
    device_types = Fleet.list_device_types()

    Enum.reduce(rows, %{created: 0, errors: []}, fn row, result ->
      case resolve_import_row(row, branches, device_types) do
        {:ok, attrs} ->
          case Fleet.create_scooter(attrs) do
            {:ok, _} -> %{result | created: result.created + 1}
            {:error, changeset} ->
              error = "ردیف #{row["row_number"]}: #{changeset_error(changeset)}"
              %{result | errors: result.errors ++ [error]}
          end

        {:error, reason} ->
          %{result | errors: result.errors ++ ["ردیف #{row["row_number"]}: #{reason}"]}
      end
    end)
  end

  defp resolve_import_row(row, branches, device_types) do
    plate = clean_import_value(row["plate"])
    barcode = clean_import_value(row["qrscan"])
    branch_name = clean_import_value(row["branch"])
    device_type_name = clean_import_value(row["devicetype"])

    cond do
      plate == "" -> {:error, "پلاک خالی است."}
      barcode == "" -> {:error, "مقدار QR خالی است."}
      branch_name == "" -> {:error, "نام شعبه خالی است."}
      device_type_name == "" -> {:error, "مدل دستگاه خالی است."}
      true ->
        with {:ok, branch} <- find_branch(branches, branch_name),
             {:ok, device_type} <- find_device_type(device_types, device_type_name) do
          {:ok, %{
            plate: plate,
            barcode: barcode,
            model: device_type.device_model || device_type.name,
            status: "active",
            branch_id: branch.id,
            current_branch_id: branch.id,
            device_type_id: device_type.id
          }}
        end
    end
  end

  defp find_branch(branches, name) do
    normalized = normalize_import_lookup(name)

    case Enum.find(branches, fn branch ->
           normalize_import_lookup(branch.name) == normalized or
             normalize_import_lookup(branch.code) == normalized
         end) do
      nil -> {:error, "شعبه «#{name}» در سیستم پیدا نشد."}
      branch -> {:ok, branch}
    end
  end

  defp find_device_type(device_types, name) do
    normalized = normalize_import_lookup(name)

    case Enum.find(device_types, fn device_type ->
           [device_type.device_model, device_type.name, device_type.device_identifier, device_type.code]
           |> Enum.reject(&is_nil/1)
           |> Enum.any?(&(normalize_import_lookup(&1) == normalized))
         end) do
      nil -> {:error, "مدل دستگاه «#{name}» در سیستم پیدا نشد."}
      device_type -> {:ok, device_type}
    end
  end

  defp normalize_import_lookup(value) do
    value
    |> clean_import_value()
    |> String.downcase()
    |> String.replace("ي", "ی")
    |> String.replace("ك", "ک")
    |> String.replace(~r/\s+/u, " ")
  end

  defp clean_import_value(value), do: value |> to_string() |> String.trim()

  defp changeset_error(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Enum.reduce(opts, message, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
    |> Enum.flat_map(fn {field, messages} -> Enum.map(messages, &"#{field} #{&1}") end)
    |> Enum.join("، ")
  end

  defp summarize_import_errors([]), do: nil
  defp summarize_import_errors(errors) do
    shown = errors |> Enum.take(6) |> Enum.join(" | ")
    extra = max(length(errors) - 6, 0)
    if extra > 0, do: "#{shown} | و #{extra} خطای دیگر", else: shown
  end

  defp maybe_put_import_error(conn, nil), do: conn
  defp maybe_put_import_error(conn, message), do: put_flash(conn, :error, message)

  def show(conn, %{"id" => id}) do
    render(conn, :show, scooter: Fleet.get_scooter_with_details!(id))
  end

  def edit(conn, %{"id" => id}) do
    scooter = Fleet.get_scooter_with_details!(id)
    changeset = Fleet.change_scooter(scooter)

    render(conn, :edit,
      scooter: scooter,
      form: Phoenix.Component.to_form(changeset),
      branches: Operations.list_branches(),
      device_types: Fleet.list_device_types()
    )
  end

  def update(conn, %{"id" => id, "scooter" => scooter_params}) do
    scooter = Fleet.get_scooter!(id)

    case Fleet.update_scooter(scooter, scooter_params) do
      {:ok, scooter} ->
        conn
        |> put_flash(:info, "دستگاه ویرایش شد.")
        |> redirect(to: ~p"/scooters/#{scooter}")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :edit,
          scooter: Fleet.get_scooter_with_details!(id),
          form: Phoenix.Component.to_form(changeset),
          branches: Operations.list_branches(),
          device_types: Fleet.list_device_types()
        )
    end
  end

  def update_status(conn, %{"id" => id, "scooter" => %{"status" => status}} = params) do
    scooter = Fleet.get_scooter!(id)
    query = params |> Map.get("q", "") |> String.trim()
    attrs = quick_status_attrs(scooter, status)

    case Fleet.update_scooter(scooter, attrs) do
      {:ok, _scooter} ->
        conn
        |> put_flash(:info, "وضعیت دستگاه تغییر کرد.")
        |> redirect(to: ~p"/scooters?#{[q: query]}")

      {:error, _changeset} ->
        conn
        |> put_flash(:error, "تغییر وضعیت دستگاه انجام نشد.")
        |> redirect(to: ~p"/scooters?#{[q: query]}")
    end
  end

  def delete(conn, %{"id" => id}) do
    scooter = Fleet.get_scooter!(id)
    {:ok, _scooter} = Fleet.delete_scooter(scooter)

    conn
    |> put_flash(:info, "دستگاه حذف شد.")
    |> redirect(to: ~p"/scooters")
  end

  defp quick_status_attrs(scooter, status) when status in ["needs_service", "waiting_for_part"] do
    notes =
      scooter.notes
      |> to_string()
      |> String.trim()

    %{
      status: status,
      notes: if(notes == "", do: "تغییر وضعیت توسط ادمین", else: notes)
    }
  end

  defp quick_status_attrs(_scooter, status), do: %{status: status}
end
