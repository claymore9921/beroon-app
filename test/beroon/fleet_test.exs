defmodule Beroon.FleetTest do
  use Beroon.DataCase

  alias Beroon.Fleet

  describe "scooters" do
    alias Beroon.Fleet.Scooter

    import Beroon.FleetFixtures
    import Beroon.OperationsFixtures

    @invalid_attrs %{
      status: nil,
      plate: nil,
      barcode: nil,
      model: nil,
      notes: nil,
      device_type_id: nil
    }

    test "list_scooters/0 returns all scooters" do
      scooter = scooter_fixture()
      assert Fleet.list_scooters() == [scooter]
    end

    test "get_scooter!/1 returns the scooter with given id" do
      scooter = scooter_fixture()
      assert Fleet.get_scooter!(scooter.id) == scooter
    end

    test "create_scooter/1 with valid data creates a scooter" do
      branch = branch_fixture()
      device_type = device_type_fixture()

      valid_attrs = %{
        branch_id: branch.id,
        device_type_id: device_type.id,
        status: "active",
        plate: "some plate",
        barcode: "some barcode",
        model: "some model",
        notes: "some notes"
      }

      assert {:ok, %Scooter{} = scooter} = Fleet.create_scooter(valid_attrs)
      assert scooter.status == "active"
      assert scooter.plate == "some plate"
      assert scooter.barcode == "some barcode"
      assert scooter.model == "some model"
      assert scooter.notes == "some notes"
    end

    test "create_scooter/1 requires notes for repair and waiting statuses" do
      branch = branch_fixture()
      device_type = device_type_fixture()

      base_attrs = %{
        branch_id: branch.id,
        device_type_id: device_type.id,
        plate: "repair plate",
        barcode: "repair barcode",
        model: "some model"
      }

      assert {:error, %Ecto.Changeset{}} =
               Fleet.create_scooter(Map.put(base_attrs, :status, "needs_service"))

      assert {:error, %Ecto.Changeset{}} =
               Fleet.create_scooter(
                 base_attrs
                 |> Map.put(:plate, "part plate")
                 |> Map.put(:barcode, "part barcode")
                 |> Map.put(:status, "waiting_for_part")
               )

      assert {:ok, %Scooter{} = scooter} =
               Fleet.create_scooter(
                 base_attrs
                 |> Map.put(:plate, "fixed plate")
                 |> Map.put(:barcode, "fixed barcode")
                 |> Map.put(:status, "needs_service")
                 |> Map.put(:notes, "لاستیک نیاز به تعویض دارد")
               )

      assert scooter.status == "needs_service"
    end

    test "create_scooter/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Fleet.create_scooter(@invalid_attrs)
    end

    test "update_scooter/2 with valid data updates the scooter" do
      scooter = scooter_fixture()

      update_attrs = %{
        status: "out_of_service",
        plate: "some updated plate",
        barcode: "some updated barcode",
        model: "some updated model",
        notes: "some updated notes"
      }

      assert {:ok, %Scooter{} = scooter} = Fleet.update_scooter(scooter, update_attrs)
      assert scooter.status == "out_of_service"
      assert scooter.plate == "some updated plate"
      assert scooter.barcode == "some updated barcode"
      assert scooter.model == "some updated model"
      assert scooter.notes == "some updated notes"
    end

    test "update_scooter/2 with invalid data returns error changeset" do
      scooter = scooter_fixture()
      assert {:error, %Ecto.Changeset{}} = Fleet.update_scooter(scooter, @invalid_attrs)
      assert scooter == Fleet.get_scooter!(scooter.id)
    end

    test "delete_scooter/1 deletes the scooter" do
      scooter = scooter_fixture()
      assert {:ok, %Scooter{}} = Fleet.delete_scooter(scooter)
      assert_raise Ecto.NoResultsError, fn -> Fleet.get_scooter!(scooter.id) end
    end

    test "change_scooter/1 returns a scooter changeset" do
      scooter = scooter_fixture()
      assert %Ecto.Changeset{} = Fleet.change_scooter(scooter)
    end
  end
end
