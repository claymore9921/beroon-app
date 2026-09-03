defmodule Beroon.Repo.Migrations.CreateChecklistItems do
  use Ecto.Migration

  def change do
    create table(:checklist_items) do
      add :title, :string
      add :description, :text
      add :required, :boolean, default: false, null: false
      add :position, :integer
      add :active, :boolean, default: false, null: false

      timestamps(type: :utc_datetime)
    end
  end
end
