defmodule Beroon.Repo.Migrations.CreateBranchNotifications do
  use Ecto.Migration

  def change do
    create table(:branch_notifications) do
      add :subject, :string, null: false
      add :body, :string, null: false
      add :sent_by_admin_phone, :string
      add :sent_at, :utc_datetime, null: false

      timestamps(type: :utc_datetime)
    end

    create table(:branch_notification_recipients) do
      add :notification_id, references(:branch_notifications, on_delete: :delete_all), null: false
      add :branch_id, references(:branches, on_delete: :delete_all), null: false
      add :read_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:branch_notification_recipients, [:branch_id, :read_at])
    create index(:branch_notification_recipients, [:notification_id])

    create unique_index(:branch_notification_recipients, [:notification_id, :branch_id],
             name: :branch_notification_recipients_unique_branch_index
           )
  end
end
