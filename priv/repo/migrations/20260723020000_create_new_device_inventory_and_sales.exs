defmodule Beroon.Repo.Migrations.CreateNewDeviceInventoryAndSales do
  use Ecto.Migration
  def change do
    create table(:new_device_stocks) do
      add :device_type_id, references(:device_types, on_delete: :delete_all), null: false
      add :quantity, :integer, null: false, default: 0
      timestamps(type: :utc_datetime)
    end
    create unique_index(:new_device_stocks, [:device_type_id])
    create table(:new_device_sales) do
      add :device_type_id, references(:device_types, on_delete: :restrict), null: false
      add :quantity, :integer, null: false
      add :unit_price, :bigint, null: false
      add :sold_at, :utc_datetime, null: false
      add :sold_by_phone, :string
      add :notes, :text
      timestamps(type: :utc_datetime)
    end
    create index(:new_device_sales, [:device_type_id])
    create index(:new_device_sales, [:sold_at])
  end
end
