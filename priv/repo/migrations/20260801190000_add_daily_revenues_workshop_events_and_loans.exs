defmodule Beroon.Repo.Migrations.AddDailyRevenuesWorkshopEventsAndLoans do
  use Ecto.Migration

  def change do
    create table(:daily_revenues) do
      add :branch_id, references(:branches, on_delete: :delete_all), null: false
      add :reported_on, :date, null: false
      add :cash_amount, :bigint, null: false, default: 0
      add :card_to_card_amount, :bigint, null: false, default: 0
      add :registered_by_phone, :string
      timestamps(type: :utc_datetime)
    end

    create unique_index(:daily_revenues, [:branch_id, :reported_on])

    create table(:workshop_events) do
      add :scooter_id, references(:scooters, on_delete: :delete_all), null: false
      add :event_type, :string, null: false
      add :event_on, :date, null: false
      add :event_at, :utc_datetime, null: false
      add :registered_by_phone, :string
      timestamps(type: :utc_datetime)
    end

    create index(:workshop_events, [:event_on, :event_type])
    create index(:workshop_events, [:scooter_id])

    create table(:scooter_loans) do
      add :scooter_id, references(:scooters, on_delete: :delete_all), null: false
      add :unit_name, :string, null: false
      add :previous_status, :string, null: false
      add :loaned_at, :utc_datetime, null: false
      add :returned_at, :utc_datetime
      add :registered_by_phone, :string
      add :notes, :text
      timestamps(type: :utc_datetime)
    end

    create index(:scooter_loans, [:scooter_id])
    create unique_index(:scooter_loans, [:scooter_id], where: "returned_at IS NULL", name: :one_open_loan_per_scooter)
  end
end
