defmodule Beroon.Repo.Migrations.AddManagerPhoneToBranches do
  use Ecto.Migration

  def change do
    alter table(:branches) do
      add :manager_phone, :string
    end

    create index(:branches, [:manager_phone])
  end
end
