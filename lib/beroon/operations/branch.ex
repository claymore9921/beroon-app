defmodule Beroon.Operations.Branch do
  use Ecto.Schema
  import Ecto.Changeset

  schema "branches" do
    field :name, :string
    field :code, :string
    field :manager_name, :string
    field :manager_phone, :string
    field :manager_phone_secondary, :string
    field :kind, :string, default: "branch"
    field :active, :boolean, default: false
    field :dinner_open_weekdays, {:array, :integer}, default: [4, 5]

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(branch, attrs) do
    branch
    |> cast(attrs, [:name, :code, :manager_name, :manager_phone, :manager_phone_secondary, :kind, :active, :dinner_open_weekdays])
    |> validate_required([:name, :code, :manager_name, :kind, :active])
    |> validate_inclusion(:kind, ["branch", "workshop"])
  end
end
