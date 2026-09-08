defmodule Beroon.Repo.Migrations.AddDinnerOpenWeekdaysToBranches do
  use Ecto.Migration

  def change do
    alter table(:branches) do
      # روزهای هفته که آمار شام برای این شعبه باز است (۱=دوشنبه ... ۷=یکشنبه، طبق
      # استاندارد ISO 8601؛ پنجشنبه=۴ و جمعه=۵). پیش‌فرض همان رفتار قبلی است.
      add :dinner_open_weekdays, {:array, :integer}, null: false, default: [4, 5]
    end
  end
end
