defmodule Beroon.Reports.BranchNotificationRecipient do
  use Ecto.Schema
  import Ecto.Changeset

  schema "branch_notification_recipients" do
    field :read_at, :utc_datetime
    field :notification_id, :id
    field :branch_id, :id

    timestamps(type: :utc_datetime)
  end

  def changeset(recipient, attrs) do
    recipient
    |> cast(attrs, [:notification_id, :branch_id, :read_at])
    |> validate_required([:notification_id, :branch_id])
    |> unique_constraint([:notification_id, :branch_id],
      name: :branch_notification_recipients_unique_branch_index
    )
  end
end
