defmodule Beroon.Repo.Migrations.CreateDeviceTypes do
  use Ecto.Migration

  def change do
    create table(:device_types) do
      add :name, :string, null: false
      add :code, :string, null: false
      add :description, :text
      add :active, :boolean, null: false, default: true

      timestamps(type: :utc_datetime)
    end

    create unique_index(:device_types, [:code])
  end
end
