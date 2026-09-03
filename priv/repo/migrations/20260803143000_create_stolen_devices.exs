defmodule Beroon.Repo.Migrations.CreateStolenDevices do
  use Ecto.Migration

  def change do
    create table(:stolen_devices) do
      add :scooter_id, references(:scooters, on_delete: :delete_all)
      add :branch_id, references(:branches, on_delete: :restrict), null: false
      add :device_type_id, references(:device_types, on_delete: :restrict), null: false
      add :quantity, :integer, null: false, default: 1
      add :plate_snapshot, :string
      add :previous_status, :string
      add :reported_at, :utc_datetime, null: false
      add :recovered_at, :utc_datetime
      add :registered_by_phone, :string
      add :notes, :text

      timestamps(type: :utc_datetime)
    end

    create index(:stolen_devices, [:branch_id])
    create index(:stolen_devices, [:device_type_id])
    create index(:stolen_devices, [:reported_at])

    create unique_index(:stolen_devices, [:scooter_id],
             where: "scooter_id IS NOT NULL AND recovered_at IS NULL",
             name: :one_open_theft_per_scooter
           )

    create constraint(:stolen_devices, :stolen_devices_quantity_must_be_positive,
             check: "quantity > 0"
           )
  end
end
