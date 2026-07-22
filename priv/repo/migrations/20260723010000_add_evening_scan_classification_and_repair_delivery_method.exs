defmodule Beroon.Repo.Migrations.AddEveningScanClassificationAndRepairDeliveryMethod do
  use Ecto.Migration

  def change do
    alter table(:evening_counts) do
      add :expected_scooter_ids, {:array, :bigint}, null: false, default: []
    end

    alter table(:evening_count_items) do
      add :scan_result, :string, null: false, default: "expected"
      add :home_branch_id, references(:branches, on_delete: :nilify_all)
      add :current_branch_id, references(:branches, on_delete: :nilify_all)
    end

    create index(:evening_count_items, [:scan_result])
    create index(:evening_count_items, [:home_branch_id])
    create index(:evening_count_items, [:current_branch_id])

    alter table(:scooter_repair_reports) do
      add :delivery_method, :string, null: false, default: "attendant"
    end
  end
end
