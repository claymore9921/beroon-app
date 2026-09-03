defmodule Beroon.Reports.BranchNotification do
  use Ecto.Schema
  import Ecto.Changeset

  schema "branch_notifications" do
    field :subject, :string
    field :body, :string
    field :sent_by_admin_phone, :string
    field :sent_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  def changeset(notification, attrs) do
    notification
    |> cast(attrs, [:subject, :body, :sent_by_admin_phone, :sent_at])
    |> validate_required([:subject, :body, :sent_at])
  end
end
