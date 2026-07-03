defmodule Beroon.Repo.Migrations.RemoveUnusedScooterFields do
  use Ecto.Migration

  def change do
    drop_if_exists unique_index(:scooters, [:asset_id])

    alter table(:scooters) do
      remove :asset_id, :string
      remove :color, :string
    end
  end
end
