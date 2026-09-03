defmodule Beroon.Reports.DinnerReport do
  use Ecto.Schema
  import Ecto.Changeset

  schema "dinner_reports" do
    field :reported_on, :date
    field :attendant_count, :integer, default: 0
    field :attendant_names, {:array, :string}, default: []
    field :registered_by_phone, :string
    belongs_to :branch, Beroon.Operations.Branch
    timestamps(type: :utc_datetime)
  end

  def changeset(dinner_report, attrs) do
    dinner_report
    |> cast(attrs, [:branch_id, :reported_on, :attendant_count, :attendant_names, :registered_by_phone])
    |> normalize_names()
    |> validate_required([:branch_id, :reported_on, :attendant_count])
    |> validate_number(:attendant_count, greater_than_or_equal_to: 0)
    |> unique_constraint([:branch_id, :reported_on])
  end

  defp normalize_names(changeset) do
    case get_change(changeset, :attendant_names) do
      nil ->
        changeset

      names ->
        cleaned =
          names
          |> List.wrap()
          |> Enum.map(&String.trim(to_string(&1 || "")))
          |> Enum.reject(&(&1 == ""))

        changeset
        |> put_change(:attendant_names, cleaned)
        |> put_change(:attendant_count, length(cleaned))
    end
  end
end
