defmodule Beroon.Repo.Migrations.CreateScooterLocationEvents do
  use Ecto.Migration

  def up do
    create table(:scooter_location_events) do
      add :scooter_id, references(:scooters, on_delete: :delete_all), null: false
      add :branch_id, references(:branches, on_delete: :nilify_all)
      add :observed_at, :utc_datetime, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:scooter_location_events, [:scooter_id, :observed_at])
    create index(:scooter_location_events, [:branch_id])

    # Backfill historical positions already present in the application so the
    # admin page is useful immediately after the migration.
    execute("""
    INSERT INTO scooter_location_events (scooter_id, branch_id, observed_at, inserted_at, updated_at)
    SELECT scooter_id, current_branch_id, inserted_at, inserted_at, inserted_at
    FROM evening_count_items
    WHERE scooter_id IS NOT NULL AND current_branch_id IS NOT NULL
    """)

    execute("""
    INSERT INTO scooter_location_events (scooter_id, branch_id, observed_at, inserted_at, updated_at)
    SELECT scooter_id, branch_id, COALESCE(checked_at, inserted_at), inserted_at, inserted_at
    FROM morning_inspections
    WHERE scooter_id IS NOT NULL AND branch_id IS NOT NULL
    """)

    execute("""
    INSERT INTO scooter_location_events (scooter_id, branch_id, observed_at, inserted_at, updated_at)
    SELECT scooter_id, destination_branch_id, transported_at, inserted_at, inserted_at
    FROM scooter_transports
    WHERE scooter_id IS NOT NULL AND destination_branch_id IS NOT NULL
    """)

    execute("""
    INSERT INTO scooter_location_events (scooter_id, branch_id, observed_at, inserted_at, updated_at)
    SELECT id, current_branch_id, updated_at, updated_at, updated_at
    FROM scooters
    WHERE current_branch_id IS NOT NULL
    """)
  end

  def down do
    drop table(:scooter_location_events)
  end
end
