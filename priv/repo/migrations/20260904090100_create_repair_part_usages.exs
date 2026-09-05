defmodule Beroon.Repo.Migrations.CreateRepairPartUsages do
  use Ecto.Migration

  def change do
    create table(:repair_part_usages) do
      add :workshop_event_id, references(:workshop_events, on_delete: :delete_all), null: false
      add :part_id, references(:parts, on_delete: :nilify_all)
      # نام قطعه در لحظه‌ی مصرف ذخیره می‌شود تا اگر بعداً قطعه ویرایش/حذف شد،
      # ریز گزارش ترخیص همچنان درست و خوانا بماند.
      add :part_name, :string, null: false
      add :quantity, :integer, null: false, default: 1

      timestamps(type: :utc_datetime)
    end

    create index(:repair_part_usages, [:workshop_event_id])
    create index(:repair_part_usages, [:part_id])
  end
end
