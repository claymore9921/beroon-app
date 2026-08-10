defmodule Beroon.Repo.Migrations.AddSecondManagerSalesRackAndRepairTechnician do
  use Ecto.Migration

  def change do
    alter table(:branches) do
      add :manager_phone_secondary, :string
    end

    create index(:branches, [:manager_phone_secondary])

    create table(:sales_rack_stocks) do
      add :device_type_id, references(:device_types, on_delete: :delete_all), null: false
      add :quantity, :integer, null: false, default: 0
      timestamps(type: :utc_datetime)
    end

    create unique_index(:sales_rack_stocks, [:device_type_id])

    alter table(:workshop_events) do
      add :technician_name, :string
      add :repair_parts_used, :text
    end

    alter table(:scooters) do
      add :repair_technician, :string
    end
  end
end
