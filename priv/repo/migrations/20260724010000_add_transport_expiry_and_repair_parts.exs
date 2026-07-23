defmodule Beroon.Repo.Migrations.AddTransportExpiryAndRepairParts do
  use Ecto.Migration

  def change do
    alter table(:scooters) do
      add :transport_until, :utc_datetime
      add :repair_parts_used, :text
    end

    create index(:scooters, [:status, :transport_until])
  end
end
