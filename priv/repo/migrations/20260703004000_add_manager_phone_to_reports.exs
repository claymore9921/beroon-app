defmodule Beroon.Repo.Migrations.AddManagerPhoneToReports do
  use Ecto.Migration

  def change do
    alter table(:morning_inspections) do
      add :manager_phone, :string
    end

    alter table(:evening_counts) do
      add :manager_phone, :string
    end

    create index(:morning_inspections, [:manager_phone, :checked_on])
    create index(:evening_counts, [:manager_phone, :counted_on])
  end
end
