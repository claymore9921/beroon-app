defmodule Beroon.Repo.Migrations.AddKindToBranches do
  use Ecto.Migration

  def change do
    alter table(:branches) do
      add :kind, :string, null: false, default: "branch"
    end

    create index(:branches, [:kind])
  end
end
