defmodule Beroon.Fleet.Scooter do
  use Ecto.Schema
  import Ecto.Changeset

  alias Beroon.Fleet.DeviceType
  alias Beroon.Operations.Branch

  @statuses [
    "active",
    "needs_service",
    "awaiting_repair",
    "repairing",
    "waiting_for_part",
    "ready_for_pickup",
    "out_of_service",
    "transport"
  ]
  @note_required_statuses ["needs_service", "waiting_for_part"]

  schema "scooters" do
    field :plate, :string
    field :barcode, :string
    field :model, :string
    field :status, :string
    field :notes, :string
    field :transport_until, :utc_datetime
    field :repair_parts_used, :string
    belongs_to :branch, Branch
    belongs_to :current_branch, Branch
    belongs_to :device_type, DeviceType

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(scooter, attrs) do
    scooter
    |> cast(attrs, [
      :plate,
      :barcode,
      :model,
      :status,
      :notes,
      :transport_until,
      :repair_parts_used,
      :branch_id,
      :current_branch_id,
      :device_type_id
    ])
    |> default_current_branch()
    |> validate_required([:plate, :barcode, :status, :branch_id, :current_branch_id, :device_type_id])
    |> validate_inclusion(:status, @statuses)
    |> validate_notes_for_repair_status()
    |> unique_constraint(:plate)
    |> unique_constraint(:barcode)
  end

  defp default_current_branch(changeset) do
    if is_nil(get_field(changeset, :current_branch_id)) do
      put_change(changeset, :current_branch_id, get_field(changeset, :branch_id))
    else
      changeset
    end
  end

  defp validate_notes_for_repair_status(changeset) do
    status = get_field(changeset, :status)

    if status in @note_required_statuses do
      validate_required(changeset, [:notes])
    else
      changeset
    end
  end
end
