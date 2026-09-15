defmodule Beroon.Repo.Migrations.CreateConsumableStockMovements do
  use Ecto.Migration

  def change do
    create table(:consumable_stock_movements) do
      add :consumable_id, references(:consumables, on_delete: :nilify_all)
      add :consumable_name, :string, null: false
      add :movement_type, :string, null: false
      add :quantity, :integer, null: false
      add :branch_id, references(:branches, on_delete: :nilify_all)
      add :registered_by_phone, :string
      add :occurred_at, :utc_datetime, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:consumable_stock_movements, [:consumable_id])
    create index(:consumable_stock_movements, [:movement_type])
    create index(:consumable_stock_movements, [:occurred_at])
  end
end
