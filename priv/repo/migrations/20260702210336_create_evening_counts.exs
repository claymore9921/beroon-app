defmodule Beroon.Repo.Migrations.CreateEveningCounts do
  use Ecto.Migration

  def change do
    create table(:evening_counts) do
      add :counted_on, :date
      add :counted_at, :utc_datetime
      add :manager_name, :string
      add :total_count, :integer
      add :available_count, :integer
      add :rented_count, :integer
      add :damaged_count, :integer
      add :missing_count, :integer
      add :notes, :text
      add :branch_id, references(:branches, on_delete: :nothing), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:evening_counts, [:branch_id])
  end
end
