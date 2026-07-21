defmodule Beroon.Repo.Migrations.ScopeMorningChecklistUniquenessToBranch do
  use Ecto.Migration

  def change do
    drop_if_exists index(:morning_inspections, [:manager_phone, :checked_on, :scooter_id],
                     name: :morning_inspections_manager_day_scooter_index
                   )

    create unique_index(:morning_inspections, [:branch_id, :checked_on, :scooter_id],
             name: :morning_inspections_branch_day_scooter_index
           )
  end
end
