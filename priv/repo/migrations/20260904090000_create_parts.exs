defmodule Beroon.Repo.Migrations.CreateParts do
  use Ecto.Migration

  def change do
    create table(:parts) do
      add :name, :string, null: false
      add :quantity, :integer, null: false, default: 0

      timestamps(type: :utc_datetime)
    end

    create unique_index(:parts, [:name])
  end
end
