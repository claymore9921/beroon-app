defmodule Beroon.Repo.Migrations.CreateScooters do
  use Ecto.Migration

  def change do
    create table(:scooters) do
      add :plate, :string
      add :barcode, :string
      add :model, :string
      add :status, :string
      add :notes, :text
      add :branch_id, references(:branches, on_delete: :nothing), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:scooters, [:branch_id])
    create unique_index(:scooters, [:plate])
    create unique_index(:scooters, [:barcode])
  end
end
