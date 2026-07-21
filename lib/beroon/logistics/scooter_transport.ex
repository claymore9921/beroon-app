defmodule Beroon.Logistics.ScooterTransport do
  use Ecto.Schema
  import Ecto.Changeset

  alias Beroon.Fleet.Scooter
  alias Beroon.Operations.Branch

  schema "scooter_transports" do
    belongs_to :scooter, Scooter
    belongs_to :origin_branch, Branch
    belongs_to :destination_branch, Branch
    belongs_to :registered_by_branch, Branch

    field :registered_by_phone, :string
    field :registered_by_name, :string
    field :transported_at, :utc_datetime
    field :notes, :string

    timestamps(type: :utc_datetime)
  end

  def changeset(transport, attrs) do
    transport
    |> cast(attrs, [
      :scooter_id,
      :origin_branch_id,
      :destination_branch_id,
      :registered_by_branch_id,
      :registered_by_phone,
      :registered_by_name,
      :transported_at,
      :notes
    ])
    |> validate_required([
      :scooter_id,
      :origin_branch_id,
      :destination_branch_id,
      :registered_by_branch_id,
      :registered_by_phone,
      :transported_at
    ])
    |> validate_different_branches()
    |> check_constraint(:destination_branch_id, name: :origin_and_destination_must_differ)
  end

  defp validate_different_branches(changeset) do
    origin_id = get_field(changeset, :origin_branch_id)
    destination_id = get_field(changeset, :destination_branch_id)

    if origin_id && destination_id && origin_id == destination_id do
      add_error(changeset, :destination_branch_id, "باید با شعبه فعلی دستگاه متفاوت باشد")
    else
      changeset
    end
  end
end
