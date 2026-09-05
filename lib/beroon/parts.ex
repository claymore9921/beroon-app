defmodule Beroon.Parts do
  import Ecto.Query, warn: false

  alias Beroon.Parts.Part
  alias Beroon.Parts.RepairPartUsage
  alias Beroon.Repo

  def list_parts do
    Part
    |> order_by([p], asc: p.name)
    |> Repo.all()
  end

  def get_part!(id), do: Repo.get!(Part, id)

  def create_part(attrs) do
    %Part{} |> Part.changeset(attrs) |> Repo.insert()
  end

  def update_part(%Part{} = part, attrs) do
    part |> Part.changeset(attrs) |> Repo.update()
  end

  def delete_part(%Part{} = part) do
    Repo.delete(part)
  end

  def change_part(%Part{} = part, attrs \\ %{}) do
    Part.changeset(part, attrs)
  end

  @doc """
  ثبت قطعات مصرف‌شده برای یک رخداد ترخیص و کسر همان تعداد از موجودی انبار.
  parts_input یک لیست از %{"part_id" => id, "quantity" => qty} است.
  """
  def record_usages(workshop_event_id, parts_input) when is_list(parts_input) do
    Repo.transaction(fn ->
      Enum.map(parts_input, fn %{part_id: part_id, quantity: quantity} ->
        part = part_id && Repo.get(Part, part_id)

        usage_attrs = %{
          workshop_event_id: workshop_event_id,
          part_id: part && part.id,
          part_name: (part && part.name) || "قطعه نامشخص",
          quantity: quantity
        }

        case %RepairPartUsage{} |> RepairPartUsage.changeset(usage_attrs) |> Repo.insert() do
          {:ok, usage} ->
            if part do
              from(p in Part, where: p.id == ^part.id)
              |> Repo.update_all(inc: [quantity: -quantity])
            end

            usage

          {:error, changeset} ->
            Repo.rollback(changeset)
        end
      end)
    end)
  end

  def usages_for_event(workshop_event_id) do
    RepairPartUsage
    |> where([u], u.workshop_event_id == ^workshop_event_id)
    |> order_by([u], asc: u.id)
    |> Repo.all()
  end

  @doc """
  ریز قطعات مصرف‌شده برای چند رخداد ترخیص هم‌زمان (برای گزارش اکسل)، به شکل
  یک نگاشت از workshop_event_id به لیست %{part_name:, quantity:}.
  """
  def usages_by_event(workshop_event_ids) when is_list(workshop_event_ids) do
    if workshop_event_ids == [] do
      %{}
    else
      RepairPartUsage
      |> where([u], u.workshop_event_id in ^workshop_event_ids)
      |> order_by([u], asc: u.id)
      |> select([u], %{workshop_event_id: u.workshop_event_id, part_name: u.part_name, quantity: u.quantity})
      |> Repo.all()
      |> Enum.group_by(& &1.workshop_event_id)
    end
  end
end
