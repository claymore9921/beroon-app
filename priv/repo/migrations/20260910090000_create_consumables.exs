defmodule Beroon.Repo.Migrations.CreateConsumables do
  use Ecto.Migration

  def change do
    create table(:consumables) do
      add :name, :string, null: false
      add :quantity, :integer, null: false, default: 0

      timestamps(type: :utc_datetime)
    end

    create unique_index(:consumables, [:name])
  end
end
