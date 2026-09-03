defmodule Beroon.Operations.BranchManagerRegistration do
  use Ecto.Schema
  import Ecto.Changeset

  schema "branch_manager_registrations" do
    field :phone, :string
    field :status, :string, default: "pending"
    field :requested_at, :utc_datetime
    field :approved_at, :utc_datetime
    field :branch_id, :id

    timestamps(type: :utc_datetime)
  end

  def changeset(registration, attrs) do
    registration
    |> cast(attrs, [:phone, :status, :requested_at, :approved_at, :branch_id])
    |> validate_required([:phone, :status, :requested_at])
    |> validate_inclusion(:status, ["pending", "approved"])
    |> unique_constraint(:phone)
  end
end
