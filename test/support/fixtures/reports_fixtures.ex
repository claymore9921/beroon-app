defmodule Beroon.ReportsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Beroon.Reports` context.
  """

  @doc """
  Generate a morning_inspection.
  """
  def morning_inspection_fixture(attrs \\ %{}) do
    branch =
      Beroon.OperationsFixtures.branch_fixture(%{code: "morning branch", name: "morning branch"})

    scooter = Beroon.FleetFixtures.scooter_fixture(%{branch_id: branch.id})

    {:ok, morning_inspection} =
      attrs
      |> Enum.into(%{
        branch_id: branch.id,
        checked_at: ~U[2026-07-01 21:03:00Z],
        checked_on: ~D[2026-07-01],
        manager_name: "some manager_name",
        manager_phone: "09120000000",
        notes: "some notes",
        scooter_id: scooter.id,
        status: "some status",
        submitted_before_deadline: true
      })
      |> Beroon.Reports.create_morning_inspection()

    morning_inspection
  end

  @doc """
  Generate an evening_count.
  """
  def evening_count_fixture(attrs \\ %{}) do
    branch =
      Beroon.OperationsFixtures.branch_fixture(%{code: "evening branch", name: "evening branch"})

    {:ok, evening_count} =
      attrs
      |> Enum.into(%{
        available_count: 42,
        branch_id: branch.id,
        counted_at: ~U[2026-07-01 21:03:00Z],
        counted_on: ~D[2026-07-01],
        damaged_count: 42,
        manager_name: "some manager_name",
        manager_phone: "09120000000",
        missing_count: 42,
        notes: "some notes",
        rented_count: 42,
        total_count: 42
      })
      |> Beroon.Reports.create_evening_count()

    evening_count
  end
end
