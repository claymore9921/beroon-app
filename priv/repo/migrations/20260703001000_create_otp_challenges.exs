defmodule Beroon.Repo.Migrations.CreateOtpChallenges do
  use Ecto.Migration

  def change do
    create table(:otp_challenges) do
      add :phone, :string, null: false
      add :code_hash, :string, null: false
      add :purpose, :string, null: false, default: "admin_login"
      add :attempts, :integer, null: false, default: 0
      add :expires_at, :utc_datetime, null: false
      add :consumed_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:otp_challenges, [:phone, :purpose])
    create index(:otp_challenges, [:expires_at])
  end
end
