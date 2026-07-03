defmodule Beroon.Repo.Migrations.AddIdentifierFieldsToDeviceTypesAndScooters do
  use Ecto.Migration

  def change do
    alter table(:device_types) do
      add :device_identifier, :string
      add :category, :string
      add :device_model, :string
    end

    create unique_index(:device_types, [:device_identifier])

    alter table(:scooters) do
      add :asset_id, :string
    end

    create unique_index(:scooters, [:asset_id])
  end
end
