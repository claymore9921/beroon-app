defmodule Beroon.Logistics.ScooterLoan do
  use Ecto.Schema
  import Ecto.Changeset

  schema "scooter_loans" do
    field :unit_name, :string
    field :previous_status, :string
    field :loaned_at, :utc_datetime
    field :returned_at, :utc_datetime
    field :registered_by_phone, :string
    field :notes, :string
    belongs_to :scooter, Beroon.Fleet.Scooter
    timestamps(type: :utc_datetime)
  end

  def changeset(loan, attrs) do
    loan
    |> cast(attrs, [:scooter_id, :unit_name, :previous_status, :loaned_at, :returned_at, :registered_by_phone, :notes])
    |> validate_required([:scooter_id, :unit_name, :previous_status, :loaned_at])
    |> unique_constraint(:scooter_id, name: :one_open_loan_per_scooter)
  end
end
