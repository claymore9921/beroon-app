defmodule Beroon.Repo.Migrations.CreateScooterLocationAlerts do
  use Ecto.Migration

  def change do
    create table(:scooter_location_alerts) do
      add :scooter_id, references(:scooters, on_delete: :nothing), null: false
      add :home_branch_id, references(:branches, on_delete: :nothing), null: false
      add :detected_branch_id, references(:branches, on_delete: :nothing), null: false
      add :evening_count_id, references(:evening_counts, on_delete: :delete_all), null: false
      add :detected_on, :date, null: false
      add :detected_at, :utc_datetime, null: false
      add :detected_by_manager_name, :string
      add :detected_by_manager_phone, :string
      add :resolved, :boolean, null: false, default: false

      timestamps(type: :utc_datetime)
    end

    create index(:scooter_location_alerts, [:home_branch_id, :resolved])
    create index(:scooter_location_alerts, [:detected_branch_id])
    create index(:scooter_location_alerts, [:detected_on])

    create unique_index(
             :scooter_location_alerts,
             [:scooter_id, :home_branch_id, :detected_branch_id, :detected_on],
             name: :scooter_location_alerts_unique_daily_mismatch_index
           )
  end
end
