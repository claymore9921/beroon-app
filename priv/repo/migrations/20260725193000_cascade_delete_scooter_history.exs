defmodule Beroon.Repo.Migrations.CascadeDeleteScooterHistory do
  use Ecto.Migration

  def up do
    drop constraint(:morning_inspections, "morning_inspections_scooter_id_fkey")
    alter table(:morning_inspections) do
      modify :scooter_id, references(:scooters, on_delete: :delete_all), null: false
    end

    drop constraint(:evening_count_items, "evening_count_items_scooter_id_fkey")
    alter table(:evening_count_items) do
      modify :scooter_id, references(:scooters, on_delete: :delete_all), null: false
    end

    drop constraint(:scooter_location_alerts, "scooter_location_alerts_scooter_id_fkey")
    alter table(:scooter_location_alerts) do
      modify :scooter_id, references(:scooters, on_delete: :delete_all), null: false
    end

    drop constraint(:scooter_repair_reports, "scooter_repair_reports_scooter_id_fkey")
    alter table(:scooter_repair_reports) do
      modify :scooter_id, references(:scooters, on_delete: :delete_all), null: false
    end
  end

  def down do
    drop constraint(:morning_inspections, "morning_inspections_scooter_id_fkey")
    alter table(:morning_inspections) do
      modify :scooter_id, references(:scooters, on_delete: :nothing), null: false
    end

    drop constraint(:evening_count_items, "evening_count_items_scooter_id_fkey")
    alter table(:evening_count_items) do
      modify :scooter_id, references(:scooters, on_delete: :nothing), null: false
    end

    drop constraint(:scooter_location_alerts, "scooter_location_alerts_scooter_id_fkey")
    alter table(:scooter_location_alerts) do
      modify :scooter_id, references(:scooters, on_delete: :nothing), null: false
    end

    drop constraint(:scooter_repair_reports, "scooter_repair_reports_scooter_id_fkey")
    alter table(:scooter_repair_reports) do
      modify :scooter_id, references(:scooters, on_delete: :nothing), null: false
    end
  end
end
