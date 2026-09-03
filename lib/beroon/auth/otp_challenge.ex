defmodule Beroon.Auth.OtpChallenge do
  use Ecto.Schema
  import Ecto.Changeset

  schema "otp_challenges" do
    field :phone, :string
    field :code_hash, :string
    field :purpose, :string, default: "admin_login"
    field :attempts, :integer, default: 0
    field :expires_at, :utc_datetime
    field :consumed_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  def changeset(challenge, attrs) do
    challenge
    |> cast(attrs, [:phone, :code_hash, :purpose, :attempts, :expires_at, :consumed_at])
    |> validate_required([:phone, :code_hash, :purpose, :attempts, :expires_at])
  end
end
