defmodule Beroon.Repo.Migrations.RemoveOutOfServiceStatus do
  use Ecto.Migration

  def up do
    # وضعیت «از مدار خارج» عملاً بلااستفاده و گیج‌کننده بود. دستگاه‌هایی که
    # دیگر استفاده نمی‌شوند در عمل با وضعیت «در انتظار قطعه» مدیریت می‌شوند
    # (چون در صورت رسیدن قطعه می‌توانند به چرخه برگردند)، پس هر رکورد قدیمی
    # با این وضعیت به همان‌جا منتقل می‌شود.
    execute("""
    UPDATE scooters
    SET status = 'waiting_for_part',
        notes = COALESCE(NULLIF(notes, ''), 'از مدار خارج (قدیمی)')
    WHERE status = 'out_of_service'
    """)
  end

  def down do
    :ok
  end
end
