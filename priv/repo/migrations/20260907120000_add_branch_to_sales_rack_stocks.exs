defmodule Beroon.Repo.Migrations.AddBranchToSalesRackStocks do
  use Ecto.Migration

  def change do
    alter table(:sales_rack_stocks) do
      add :branch_id, references(:branches, on_delete: :delete_all)
    end

    # قبلاً موجودی رگال فروش سراسری بود (بدون شعبه)؛ چون دیگر معنایی ندارد،
    # داده‌ی قدیمی بدون شعبه پاک می‌شود تا ادمین دوباره به تفکیک هر شعبه ثبت کند.
    execute("DELETE FROM sales_rack_stocks WHERE branch_id IS NULL", "")

    drop_if_exists unique_index(:sales_rack_stocks, [:device_type_id])
    create unique_index(:sales_rack_stocks, [:device_type_id, :branch_id])
    create index(:sales_rack_stocks, [:branch_id])
  end
end
