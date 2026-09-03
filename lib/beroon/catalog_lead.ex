defmodule Beroon.CatalogLead do
  use Ecto.Schema
  import Ecto.Changeset

  schema "catalog_leads" do
    field :name, :string
    field :phone, :string
    timestamps(type: :utc_datetime)
  end

  def changeset(lead, attrs) do
    lead
    |> cast(attrs, [:name, :phone])
    |> update_change(:name, &String.trim/1)
    |> update_change(:phone, &String.trim/1)
    |> validate_required([:name, :phone])
    |> validate_length(:name, min: 2, max: 80)
    |> validate_format(:phone, ~r/^09\d{9}$/, message: "شماره موبایل باید ۱۱ رقمی و با 09 شروع شود")
  end
end
