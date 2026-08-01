defmodule Beroon.Reports.DailyRevenue do
  use Ecto.Schema
  import Ecto.Changeset

  schema "daily_revenues" do
    field :reported_on, :date
    field :cash_amount, :integer, default: 0
    field :card_to_card_amount, :integer, default: 0
    field :registered_by_phone, :string
    belongs_to :branch, Beroon.Operations.Branch
    timestamps(type: :utc_datetime)
  end

  def changeset(revenue, attrs) do
    revenue
    |> cast(attrs, [:branch_id, :reported_on, :cash_amount, :card_to_card_amount, :registered_by_phone])
    |> validate_required([:branch_id, :reported_on, :cash_amount, :card_to_card_amount])
    |> validate_number(:cash_amount, greater_than_or_equal_to: 0)
    |> validate_number(:card_to_card_amount, greater_than_or_equal_to: 0)
    |> unique_constraint([:branch_id, :reported_on])
  end
end
