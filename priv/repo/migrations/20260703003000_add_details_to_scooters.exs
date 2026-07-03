defmodule Beroon.Repo.Migrations.AddDetailsToScooters do
  use Ecto.Migration

  def change do
    alter table(:scooters) do
      add :color, :string
      add :device_type_id, references(:device_types, on_delete: :nilify_all)
    end

    create index(:scooters, [:device_type_id])
  end
end
