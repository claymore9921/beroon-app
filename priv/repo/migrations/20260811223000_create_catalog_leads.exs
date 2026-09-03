defmodule Beroon.Repo.Migrations.CreateCatalogLeads do
  use Ecto.Migration
  def change do
    create table(:catalog_leads) do
      add :name, :string, null: false
      add :phone, :string, null: false
      timestamps(type: :utc_datetime)
    end
    create index(:catalog_leads, [:inserted_at])
  end
end
