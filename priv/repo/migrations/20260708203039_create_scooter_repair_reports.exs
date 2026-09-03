defmodule Beroon.Repo.Migrations.CreateScooterRepairReports do
  use Ecto.Migration

  def change do
    create table(:scooter_repair_reports) do
      add :scooter_id, references(:scooters, on_delete: :nothing), null: false
      add :branch_id, references(:branches, on_delete: :nothing), null: false
      add :reported_by_manager_name, :string
      add :reported_by_manager_phone, :string
      add :notes, :string, null: false
      add :reported_on, :date, null: false
      add :reported_at, :utc_datetime, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:scooter_repair_reports, [:branch_id, :reported_on])
    create index(:scooter_repair_reports, [:scooter_id])
    create index(:scooter_repair_reports, [:reported_at])
  end
end
