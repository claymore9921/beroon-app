defmodule Beroon.Consumables.ConsumableRequest do
  use Ecto.Schema
  import Ecto.Changeset

  schema "consumable_requests" do
    field :status, :string, default: "pending"
    field :requested_by_phone, :string
    field :decided_by_phone, :string
    field :decided_at, :utc_datetime
    field :requested_at, :utc_datetime
    belongs_to :branch, Beroon.Operations.Branch
    has_many :items, Beroon.Consumables.ConsumableRequestItem

    timestamps(type: :utc_datetime)
  end

  def changeset(request, attrs) do
    request
    |> cast(attrs, [:branch_id, :status, :requested_by_phone, :decided_by_phone, :decided_at, :requested_at])
    |> validate_required([:branch_id, :status, :requested_at])
    |> validate_inclusion(:status, ["pending", "approved", "rejected"])
  end
end
