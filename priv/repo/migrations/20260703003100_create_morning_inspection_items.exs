defmodule Beroon.Repo.Migrations.CreateMorningInspectionItems do
  use Ecto.Migration

  def change do
    create table(:morning_inspection_items) do
      add :morning_inspection_id, references(:morning_inspections, on_delete: :delete_all),
        null: false

      add :checklist_item_id, references(:checklist_items, on_delete: :nothing), null: false
      add :checked, :boolean, null: false, default: false

      timestamps(type: :utc_datetime)
    end

    create index(:morning_inspection_items, [:morning_inspection_id])
    create index(:morning_inspection_items, [:checklist_item_id])
    create unique_index(:morning_inspection_items, [:morning_inspection_id, :checklist_item_id])
  end
end
