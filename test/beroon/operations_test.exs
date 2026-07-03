defmodule Beroon.OperationsTest do
  use Beroon.DataCase

  alias Beroon.Operations

  describe "branches" do
    alias Beroon.Operations.Branch

    import Beroon.OperationsFixtures

    @invalid_attrs %{active: nil, code: nil, name: nil, manager_name: nil}

    test "list_branches/0 returns all branches" do
      branch = branch_fixture()
      assert Operations.list_branches() == [branch]
    end

    test "get_branch!/1 returns the branch with given id" do
      branch = branch_fixture()
      assert Operations.get_branch!(branch.id) == branch
    end

    test "create_branch/1 with valid data creates a branch" do
      valid_attrs = %{
        active: true,
        code: "some code",
        name: "some name",
        manager_name: "some manager_name"
      }

      assert {:ok, %Branch{} = branch} = Operations.create_branch(valid_attrs)
      assert branch.active == true
      assert branch.code == "some code"
      assert branch.name == "some name"
      assert branch.manager_name == "some manager_name"
    end

    test "create_branch/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Operations.create_branch(@invalid_attrs)
    end

    test "update_branch/2 with valid data updates the branch" do
      branch = branch_fixture()

      update_attrs = %{
        active: false,
        code: "some updated code",
        name: "some updated name",
        manager_name: "some updated manager_name"
      }

      assert {:ok, %Branch{} = branch} = Operations.update_branch(branch, update_attrs)
      assert branch.active == false
      assert branch.code == "some updated code"
      assert branch.name == "some updated name"
      assert branch.manager_name == "some updated manager_name"
    end

    test "update_branch/2 with invalid data returns error changeset" do
      branch = branch_fixture()
      assert {:error, %Ecto.Changeset{}} = Operations.update_branch(branch, @invalid_attrs)
      assert branch == Operations.get_branch!(branch.id)
    end

    test "delete_branch/1 deletes the branch" do
      branch = branch_fixture()
      assert {:ok, %Branch{}} = Operations.delete_branch(branch)
      assert_raise Ecto.NoResultsError, fn -> Operations.get_branch!(branch.id) end
    end

    test "change_branch/1 returns a branch changeset" do
      branch = branch_fixture()
      assert %Ecto.Changeset{} = Operations.change_branch(branch)
    end
  end
end
