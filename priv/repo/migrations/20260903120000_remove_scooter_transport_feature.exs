defmodule Beroon.Repo.Migrations.RemoveScooterTransportFeature do
  use Ecto.Migration

  def up do
    # هر دستگاهی که هنوز در وضعیت قدیمی «حمل‌ونقل» مانده، فعال می‌شود. مالکیت
    # (branch_id) دستگاه دست‌نخورده باقی می‌ماند؛ current_branch_id (محل فعلی
    # که همان شعبه مقصد حمل‌ونقل قبلی است) هم دست‌نخورده می‌ماند، چون همان
    # مفهوم «جابجا شده» است که از این به بعد با اسکن آمار شب مشخص می‌شود.
    execute("""
    UPDATE scooters
    SET status = 'active'
    WHERE status = 'transport'
    """)

    alter table(:scooters) do
      remove :transport_until
    end

    drop_if_exists table(:scooter_transports)
  end

  def down do
    create table(:scooter_transports) do
      add :scooter_id, references(:scooters, on_delete: :delete_all), null: false
      add :origin_branch_id, references(:branches, on_delete: :nilify_all)
      add :destination_branch_id, references(:branches, on_delete: :nilify_all)
      add :registered_by_branch_id, references(:branches, on_delete: :nilify_all)
      add :registered_by_phone, :string
      add :registered_by_name, :string
      add :transported_at, :utc_datetime, null: false
      add :notes, :text

      timestamps(type: :utc_datetime)
    end

    create index(:scooter_transports, [:scooter_id])
    create index(:scooter_transports, [:origin_branch_id])
    create index(:scooter_transports, [:destination_branch_id])
    create index(:scooter_transports, [:transported_at])

    alter table(:scooters) do
      add :transport_until, :utc_datetime
    end

    create index(:scooters, [:status, :transport_until])
  end
end
