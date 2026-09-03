defmodule Beroon.Repo.Migrations.CreateBranchManagerRegistrations do
  use Ecto.Migration

  def change do
    create table(:branch_manager_registrations) do
      add :phone, :string, null: false
      add :status, :string, null: false, default: "pending"
      add :requested_at, :utc_datetime, null: false
      add :approved_at, :utc_datetime
      add :branch_id, references(:branches, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create unique_index(:branch_manager_registrations, [:phone])
    create index(:branch_manager_registrations, [:status])
    create index(:branch_manager_registrations, [:branch_id])
  end
end
