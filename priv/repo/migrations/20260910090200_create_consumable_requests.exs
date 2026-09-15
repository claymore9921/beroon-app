defmodule Beroon.Repo.Migrations.CreateConsumableRequests do
  use Ecto.Migration

  def change do
    create table(:consumable_requests) do
      add :branch_id, references(:branches, on_delete: :delete_all), null: false
      add :status, :string, null: false, default: "pending"
      add :requested_by_phone, :string
      add :decided_by_phone, :string
      add :decided_at, :utc_datetime
      add :requested_at, :utc_datetime, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:consumable_requests, [:branch_id])
    create index(:consumable_requests, [:status])

    create table(:consumable_request_items) do
      add :consumable_request_id, references(:consumable_requests, on_delete: :delete_all), null: false
      add :consumable_id, references(:consumables, on_delete: :nilify_all)
      add :consumable_name, :string, null: false
      add :quantity, :integer, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:consumable_request_items, [:consumable_request_id])
  end
end
