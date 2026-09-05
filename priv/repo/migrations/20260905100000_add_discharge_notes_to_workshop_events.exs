defmodule Beroon.Repo.Migrations.AddDischargeNotesToWorkshopEvents do
  use Ecto.Migration

  def change do
    alter table(:workshop_events) do
      add :discharge_notes, :text
    end
  end
end
