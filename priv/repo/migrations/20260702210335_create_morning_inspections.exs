defmodule Beroon.Repo.Migrations.CreateMorningInspections do
  use Ecto.Migration

  def change do
    create table(:morning_inspections) do
      add :checked_on, :date
      add :checked_at, :utc_datetime
      add :manager_name, :string
      add :status, :string
      add :notes, :text
      add :submitted_before_deadline, :boolean, default: false, null: false
      add :branch_id, references(:branches, on_delete: :nothing), null: false
      add :scooter_id, references(:scooters, on_delete: :nothing), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:morning_inspections, [:branch_id])
    create index(:morning_inspections, [:scooter_id])
  end
end
