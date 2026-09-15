defmodule Beroon.Repo.Migrations.CreatePartStockMovements do
  use Ecto.Migration

  def change do
    create table(:part_stock_movements) do
      add :part_id, references(:parts, on_delete: :nilify_all)
      # نام قطعه در لحظه‌ی ثبت ذخیره می‌شود تا اگر بعداً قطعه ویرایش/حذف شد،
      # تاریخچه‌ی انبار همچنان درست و خوانا بماند.
      add :part_name, :string, null: false
      add :movement_type, :string, null: false
      add :quantity, :integer, null: false
      add :registered_by_phone, :string
      add :occurred_at, :utc_datetime, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:part_stock_movements, [:part_id])
    create index(:part_stock_movements, [:movement_type])
    create index(:part_stock_movements, [:occurred_at])
  end
end
