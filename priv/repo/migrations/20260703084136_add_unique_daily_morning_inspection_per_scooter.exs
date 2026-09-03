defmodule Beroon.Repo.Migrations.AddUniqueDailyMorningInspectionPerScooter do
  use Ecto.Migration

  def change do
    create unique_index(:morning_inspections, [:manager_phone, :checked_on, :scooter_id],
             name: :morning_inspections_manager_day_scooter_index
           )
  end
end
