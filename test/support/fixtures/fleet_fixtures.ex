defmodule Beroon.FleetFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Beroon.Fleet` context.
  """

  @doc """
  Generate a device type.
  """
  def device_type_fixture(attrs \\ %{}) do
    unique = System.unique_integer([:positive])

    {:ok, device_type} =
      attrs
      |> Enum.into(%{
        active: true,
        category: "دوچرخه برقی",
        device_identifier: "type-#{unique}",
        device_model: "H1"
      })
      |> Beroon.Fleet.create_device_type()

    device_type
  end

  @doc """
  Generate a scooter.
  """
  def scooter_fixture(attrs \\ %{}) do
    branch = Beroon.OperationsFixtures.branch_fixture()
    device_type = device_type_fixture()
    unique = System.unique_integer([:positive])

    {:ok, scooter} =
      attrs
      |> Enum.into(%{
        barcode: "barcode-#{unique}",
        branch_id: branch.id,
        device_type_id: device_type.id,
        model: "some model",
        notes: "some notes",
        plate: "plate-#{unique}",
        status: "active"
      })
      |> Beroon.Fleet.create_scooter()

    scooter
  end
end
