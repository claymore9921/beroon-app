defmodule Beroon.ReportsTest do
  use Beroon.DataCase

  alias Beroon.Reports

  describe "morning_inspections" do
    alias Beroon.Reports.MorningInspection

    import Beroon.ReportsFixtures

    defp morning_links do
      branch =
        Beroon.OperationsFixtures.branch_fixture(%{code: "morning test", name: "morning test"})

      scooter = Beroon.FleetFixtures.scooter_fixture(%{branch_id: branch.id})
      %{branch_id: branch.id, scooter_id: scooter.id}
    end

    @invalid_attrs %{
      status: nil,
      checked_on: nil,
      checked_at: nil,
      manager_name: nil,
      notes: nil,
      submitted_before_deadline: nil
    }

    test "list_morning_inspections/0 returns all morning_inspections" do
      morning_inspection = morning_inspection_fixture()
      assert Reports.list_morning_inspections() == [morning_inspection]
    end

    test "get_morning_inspection!/1 returns the morning_inspection with given id" do
      morning_inspection = morning_inspection_fixture()
      assert Reports.get_morning_inspection!(morning_inspection.id) == morning_inspection
    end

    test "create_morning_inspection/1 with valid data creates a morning_inspection" do
      valid_attrs =
        Map.merge(morning_links(), %{
          status: "some status",
          checked_on: ~D[2026-07-01],
          checked_at: ~U[2026-07-01 21:03:00Z],
          manager_name: "some manager_name",
          manager_phone: "09120000000",
          notes: "some notes",
          submitted_before_deadline: true
        })

      assert {:ok, %MorningInspection{} = morning_inspection} =
               Reports.create_morning_inspection(valid_attrs)

      assert morning_inspection.status == "some status"
      assert morning_inspection.checked_on == ~D[2026-07-01]
      assert morning_inspection.checked_at == ~U[2026-07-01 21:03:00Z]
      assert morning_inspection.manager_name == "some manager_name"
      assert morning_inspection.notes == "some notes"
      assert morning_inspection.submitted_before_deadline == true
    end

    test "create_morning_inspection/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Reports.create_morning_inspection(@invalid_attrs)
    end

    test "update_morning_inspection/2 with valid data updates the morning_inspection" do
      morning_inspection = morning_inspection_fixture()

      update_attrs = %{
        status: "some updated status",
        checked_on: ~D[2026-07-02],
        checked_at: ~U[2026-07-02 21:03:00Z],
        manager_name: "some updated manager_name",
        manager_phone: "09120000001",
        notes: "some updated notes",
        submitted_before_deadline: false
      }

      assert {:ok, %MorningInspection{} = morning_inspection} =
               Reports.update_morning_inspection(morning_inspection, update_attrs)

      assert morning_inspection.status == "some updated status"
      assert morning_inspection.checked_on == ~D[2026-07-02]
      assert morning_inspection.checked_at == ~U[2026-07-02 21:03:00Z]
      assert morning_inspection.manager_name == "some updated manager_name"
      assert morning_inspection.notes == "some updated notes"
      assert morning_inspection.submitted_before_deadline == false
    end

    test "update_morning_inspection/2 with invalid data returns error changeset" do
      morning_inspection = morning_inspection_fixture()

      assert {:error, %Ecto.Changeset{}} =
               Reports.update_morning_inspection(morning_inspection, @invalid_attrs)

      assert morning_inspection == Reports.get_morning_inspection!(morning_inspection.id)
    end

    test "delete_morning_inspection/1 deletes the morning_inspection" do
      morning_inspection = morning_inspection_fixture()
      assert {:ok, %MorningInspection{}} = Reports.delete_morning_inspection(morning_inspection)

      assert_raise Ecto.NoResultsError, fn ->
        Reports.get_morning_inspection!(morning_inspection.id)
      end
    end

    test "change_morning_inspection/1 returns a morning_inspection changeset" do
      morning_inspection = morning_inspection_fixture()
      assert %Ecto.Changeset{} = Reports.change_morning_inspection(morning_inspection)
    end
  end

  describe "evening_counts" do
    alias Beroon.Reports.EveningCount

    import Beroon.ReportsFixtures

    defp evening_links do
      branch =
        Beroon.OperationsFixtures.branch_fixture(%{code: "evening test", name: "evening test"})

      %{branch_id: branch.id}
    end

    @invalid_attrs %{
      counted_on: nil,
      counted_at: nil,
      manager_name: nil,
      total_count: nil,
      available_count: nil,
      rented_count: nil,
      damaged_count: nil,
      missing_count: nil,
      notes: nil
    }

    test "list_evening_counts/0 returns all evening_counts" do
      evening_count = evening_count_fixture()
      assert Reports.list_evening_counts() == [evening_count]
    end

    test "get_evening_count!/1 returns the evening_count with given id" do
      evening_count = evening_count_fixture()
      assert Reports.get_evening_count!(evening_count.id) == evening_count
    end

    test "create_evening_count/1 with valid data creates a evening_count" do
      valid_attrs =
        Map.merge(evening_links(), %{
          counted_on: ~D[2026-07-01],
          counted_at: ~U[2026-07-01 21:03:00Z],
          manager_name: "some manager_name",
          manager_phone: "09120000000",
          total_count: 42,
          available_count: 42,
          rented_count: 42,
          damaged_count: 42,
          missing_count: 42,
          notes: "some notes"
        })

      assert {:ok, %EveningCount{} = evening_count} = Reports.create_evening_count(valid_attrs)
      assert evening_count.counted_on == ~D[2026-07-01]
      assert evening_count.counted_at == ~U[2026-07-01 21:03:00Z]
      assert evening_count.manager_name == "some manager_name"
      assert evening_count.total_count == 42
      assert evening_count.available_count == 42
      assert evening_count.rented_count == 42
      assert evening_count.damaged_count == 42
      assert evening_count.missing_count == 42
      assert evening_count.notes == "some notes"
    end

    test "create_evening_count/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Reports.create_evening_count(@invalid_attrs)
    end

    test "update_evening_count/2 with valid data updates the evening_count" do
      evening_count = evening_count_fixture()

      update_attrs = %{
        counted_on: ~D[2026-07-02],
        counted_at: ~U[2026-07-02 21:03:00Z],
        manager_name: "some updated manager_name",
        manager_phone: "09120000001",
        total_count: 43,
        available_count: 43,
        rented_count: 43,
        damaged_count: 43,
        missing_count: 43,
        notes: "some updated notes"
      }

      assert {:ok, %EveningCount{} = evening_count} =
               Reports.update_evening_count(evening_count, update_attrs)

      assert evening_count.counted_on == ~D[2026-07-02]
      assert evening_count.counted_at == ~U[2026-07-02 21:03:00Z]
      assert evening_count.manager_name == "some updated manager_name"
      assert evening_count.total_count == 43
      assert evening_count.available_count == 43
      assert evening_count.rented_count == 43
      assert evening_count.damaged_count == 43
      assert evening_count.missing_count == 43
      assert evening_count.notes == "some updated notes"
    end

    test "update_evening_count/2 with invalid data returns error changeset" do
      evening_count = evening_count_fixture()

      assert {:error, %Ecto.Changeset{}} =
               Reports.update_evening_count(evening_count, @invalid_attrs)

      assert evening_count == Reports.get_evening_count!(evening_count.id)
    end

    test "delete_evening_count/1 deletes the evening_count" do
      evening_count = evening_count_fixture()
      assert {:ok, %EveningCount{}} = Reports.delete_evening_count(evening_count)
      assert_raise Ecto.NoResultsError, fn -> Reports.get_evening_count!(evening_count.id) end
    end

    test "change_evening_count/1 returns a evening_count changeset" do
      evening_count = evening_count_fixture()
      assert %Ecto.Changeset{} = Reports.change_evening_count(evening_count)
    end

    test "create_evening_count_with_items resolves open location alerts when scooter returns home" do
      home_branch = Beroon.OperationsFixtures.branch_fixture(%{code: "sepah", name: "سپه"})
      detected_branch = Beroon.OperationsFixtures.branch_fixture(%{code: "hafez", name: "حافظ"})

      scooter =
        Beroon.FleetFixtures.scooter_fixture(%{
          branch_id: home_branch.id,
          barcode: "return-barcode",
          plate: "RETURN-1"
        })

      {:ok, _mismatch_count} =
        Reports.create_evening_count_with_items(
          %{
            "branch_id" => detected_branch.id,
            "counted_on" => ~D[2026-07-01],
            "counted_at" => ~U[2026-07-01 21:00:00Z],
            "manager_name" => "Hafez manager",
            "manager_phone" => "09121111111",
            "total_count" => 1,
            "available_count" => 1,
            "rented_count" => 0,
            "damaged_count" => 0,
            "missing_count" => 0
          },
          [scooter]
        )

      assert [%{plate: "RETURN-1", resolved: false}] =
               Reports.list_open_location_alerts_for_home_branch(home_branch.id)

      {:ok, _home_count} =
        Reports.create_evening_count_with_items(
          %{
            "branch_id" => home_branch.id,
            "counted_on" => ~D[2026-07-02],
            "counted_at" => ~U[2026-07-02 21:00:00Z],
            "manager_name" => "Sepah manager",
            "manager_phone" => "09122222222",
            "total_count" => 1,
            "available_count" => 1,
            "rented_count" => 0,
            "damaged_count" => 0,
            "missing_count" => 0
          },
          [scooter]
        )

      assert [] = Reports.list_open_location_alerts_for_home_branch(home_branch.id)
      assert [] = Reports.list_open_location_alerts_for_date(~D[2026-07-01])

      assert [%{plate: "RETURN-1", resolved: true}] =
               Reports.list_location_alerts_for_date(~D[2026-07-01])
    end
  end
end
