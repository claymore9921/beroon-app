defmodule Beroon.Repo.Migrations.CreateEveningCountItems do
  use Ecto.Migration

  def change do
    create table(:evening_count_items) do
      add :evening_count_id, references(:evening_counts, on_delete: :delete_all), null: false
      add :scooter_id, references(:scooters, on_delete: :nothing), null: false
      add :scanned_code, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:evening_count_items, [:evening_count_id])
    create index(:evening_count_items, [:scooter_id])
    create unique_index(:evening_count_items, [:evening_count_id, :scooter_id])
  end
end
