defmodule Beroon.Repo.Migrations.CreateScooterTransportsAndCurrentLocations do
  use Ecto.Migration

  def up do
    alter table(:scooters) do
      add :current_branch_id, references(:branches, on_delete: :nilify_all)
    end

    execute("UPDATE scooters SET current_branch_id = branch_id WHERE current_branch_id IS NULL")

    alter table(:scooters) do
      modify :current_branch_id, :bigint, null: false
    end

    create index(:scooters, [:current_branch_id])

    create table(:scooter_transports) do
      add :scooter_id, references(:scooters, on_delete: :delete_all), null: false
      add :origin_branch_id, references(:branches, on_delete: :nothing), null: false
      add :destination_branch_id, references(:branches, on_delete: :nothing), null: false
      add :registered_by_branch_id, references(:branches, on_delete: :nothing), null: false
      add :registered_by_phone, :string, null: false
      add :registered_by_name, :string
      add :transported_at, :utc_datetime, null: false
      add :notes, :text

      timestamps(type: :utc_datetime)
    end

    create index(:scooter_transports, [:scooter_id])
    create index(:scooter_transports, [:origin_branch_id])
    create index(:scooter_transports, [:destination_branch_id])
    create index(:scooter_transports, [:transported_at])

    create constraint(:scooter_transports, :origin_and_destination_must_differ,
             check: "origin_branch_id <> destination_branch_id"
           )
  end

  def down do
    drop table(:scooter_transports)

    alter table(:scooters) do
      remove :current_branch_id
    end
  end
end
