defmodule Beroon.Consumables do
  import Ecto.Query, warn: false

  alias Beroon.Consumables.Consumable
  alias Beroon.Consumables.ConsumableRequest
  alias Beroon.Consumables.ConsumableRequestItem
  alias Beroon.Consumables.ConsumableStockMovement
  alias Beroon.Operations.Branch
  alias Beroon.Repo

  def list_consumables do
    Consumable
    |> order_by([c], asc: c.name)
    |> Repo.all()
  end

  def get_consumable!(id), do: Repo.get!(Consumable, id)

  def create_consumable(attrs) do
    %Consumable{} |> Consumable.changeset(attrs) |> Repo.insert()
  end

  def update_consumable(%Consumable{} = consumable, attrs) do
    consumable |> Consumable.changeset(attrs) |> Repo.update()
  end

  def delete_consumable(%Consumable{} = consumable) do
    Repo.delete(consumable)
  end

  def change_consumable(%Consumable{} = consumable, attrs \\ %{}) do
    Consumable.changeset(consumable, attrs)
  end

  @doc """
  ثبت یک «حواله مصرف» یا «خرید» شامل چند قلم کالای مصرفی، و به‌روزرسانی
  اتوماتیک موجودی انبار (کسر برای مصرف، افزودن برای خرید).
  """
  def record_stock_movements(movement_type, items, phone) when movement_type in ["consumption", "purchase"] do
    Repo.transaction(fn ->
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      sign = if movement_type == "purchase", do: 1, else: -1

      Enum.map(items, fn %{consumable_id: consumable_id, quantity: quantity} ->
        consumable = Repo.get(Consumable, consumable_id) || Repo.rollback(:consumable_not_found)

        movement_attrs = %{
          consumable_id: consumable.id,
          consumable_name: consumable.name,
          movement_type: movement_type,
          quantity: quantity,
          registered_by_phone: phone,
          occurred_at: now
        }

        case %ConsumableStockMovement{} |> ConsumableStockMovement.changeset(movement_attrs) |> Repo.insert() do
          {:ok, movement} ->
            from(c in Consumable, where: c.id == ^consumable.id)
            |> Repo.update_all(inc: [quantity: sign * quantity])

            movement

          {:error, changeset} ->
            Repo.rollback(changeset)
        end
      end)
    end)
  end

  def list_stock_movements(movement_type) when movement_type in ["consumption", "purchase"] do
    ConsumableStockMovement
    |> where([m], m.movement_type == ^movement_type)
    |> order_by([m], desc: m.occurred_at, desc: m.id)
    |> Repo.all()
  end

  # ---- درخواست شعبه و تأیید ادمین ----

  def create_request(branch_id, items, phone) when is_list(items) and items != [] do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    Repo.transaction(fn ->
      request_attrs = %{
        branch_id: branch_id,
        status: "pending",
        requested_by_phone: phone,
        requested_at: now
      }

      request =
        case %ConsumableRequest{} |> ConsumableRequest.changeset(request_attrs) |> Repo.insert() do
          {:ok, request} -> request
          {:error, changeset} -> Repo.rollback(changeset)
        end

      Enum.each(items, fn %{consumable_id: consumable_id, quantity: quantity} ->
        consumable = consumable_id && Repo.get(Consumable, consumable_id)

        item_attrs = %{
          consumable_request_id: request.id,
          consumable_id: consumable && consumable.id,
          consumable_name: (consumable && consumable.name) || "کالای نامشخص",
          quantity: quantity
        }

        case %ConsumableRequestItem{} |> ConsumableRequestItem.changeset(item_attrs) |> Repo.insert() do
          {:ok, item} -> item
          {:error, changeset} -> Repo.rollback(changeset)
        end
      end)

      request
    end)
  end

  def list_requests_for_branch(branch_id) do
    ConsumableRequest
    |> where([r], r.branch_id == ^branch_id)
    |> order_by([r], desc: r.requested_at)
    |> preload(:items)
    |> Repo.all()
  end

  def list_pending_requests do
    ConsumableRequest
    |> where([r], r.status == "pending")
    |> join(:left, [r], b in Branch, on: b.id == r.branch_id)
    |> order_by([r], asc: r.requested_at)
    |> preload([:items, :branch])
    |> Repo.all()
  end

  def list_all_requests do
    ConsumableRequest
    |> order_by([r], desc: r.requested_at)
    |> preload([:items, :branch])
    |> Repo.all()
  end

  def get_request!(id) do
    ConsumableRequest
    |> preload([:items, :branch])
    |> Repo.get!(id)
  end

  @doc """
  تأیید درخواست شعبه: برای هر قلم، به همان تعداد از موجودی انبار مصرفی کم
  می‌شود (با ثبت یک رکورد گردش انبار از نوع branch_request) و وضعیت درخواست
  «تأیید شده» می‌شود.
  """
  def approve_request(%ConsumableRequest{} = request, admin_phone) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    Repo.transaction(fn ->
      if request.status != "pending", do: Repo.rollback(:already_decided)

      Enum.each(request.items, fn item ->
        if item.consumable_id do
          movement_attrs = %{
            consumable_id: item.consumable_id,
            consumable_name: item.consumable_name,
            movement_type: "branch_request",
            quantity: item.quantity,
            branch_id: request.branch_id,
            registered_by_phone: admin_phone,
            occurred_at: now
          }

          case %ConsumableStockMovement{} |> ConsumableStockMovement.changeset(movement_attrs) |> Repo.insert() do
            {:ok, _} ->
              from(c in Consumable, where: c.id == ^item.consumable_id)
              |> Repo.update_all(inc: [quantity: -item.quantity])

            {:error, changeset} ->
              Repo.rollback(changeset)
          end
        end
      end)

      case request
           |> ConsumableRequest.changeset(%{status: "approved", decided_by_phone: admin_phone, decided_at: now})
           |> Repo.update() do
        {:ok, updated} -> updated
        {:error, changeset} -> Repo.rollback(changeset)
      end
    end)
  end

  def reject_request(%ConsumableRequest{} = request, admin_phone) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    if request.status != "pending" do
      {:error, :already_decided}
    else
      request
      |> ConsumableRequest.changeset(%{status: "rejected", decided_by_phone: admin_phone, decided_at: now})
      |> Repo.update()
    end
  end
end
