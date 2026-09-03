defmodule Beroon.Repo.Migrations.CreateDinnerReports do
  use Ecto.Migration

  def change do
    create table(:dinner_reports) do
      add :branch_id, references(:branches, on_delete: :delete_all), null: false
      add :reported_on, :date, null: false
      add :attendant_count, :integer, null: false, default: 0
      add :attendant_names, {:array, :string}, null: false, default: []
      add :registered_by_phone, :string

      timestamps(type: :utc_datetime)
    end

    create unique_index(:dinner_reports, [:branch_id, :reported_on])
  end
end
