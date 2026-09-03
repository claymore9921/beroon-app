defmodule Beroon.Repo.Migrations.CreateBranches do
  use Ecto.Migration

  def change do
    create table(:branches) do
      add :name, :string
      add :code, :string
      add :manager_name, :string
      add :active, :boolean, default: true, null: false

      timestamps(type: :utc_datetime)
    end
  end
end
