defmodule Beroon.ChecklistsTest do
  use Beroon.DataCase

  alias Beroon.Checklists

  describe "checklist_items" do
    alias Beroon.Checklists.ChecklistItem

    import Beroon.ChecklistsFixtures

    @invalid_attrs %{active: nil, position: nil, description: nil, title: nil, required: nil}

    test "list_checklist_items/0 returns all checklist_items" do
      checklist_item = checklist_item_fixture()
      assert Checklists.list_checklist_items() == [checklist_item]
    end

    test "get_checklist_item!/1 returns the checklist_item with given id" do
      checklist_item = checklist_item_fixture()
      assert Checklists.get_checklist_item!(checklist_item.id) == checklist_item
    end

    test "create_checklist_item/1 with valid data creates a checklist_item" do
      valid_attrs = %{
        active: true,
        position: 42,
        description: "some description",
        title: "some title",
        required: true
      }

      assert {:ok, %ChecklistItem{} = checklist_item} =
               Checklists.create_checklist_item(valid_attrs)

      assert checklist_item.active == true
      assert checklist_item.position == 42
      assert checklist_item.description == "some description"
      assert checklist_item.title == "some title"
      assert checklist_item.required == true
    end

    test "create_checklist_item/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Checklists.create_checklist_item(@invalid_attrs)
    end

    test "update_checklist_item/2 with valid data updates the checklist_item" do
      checklist_item = checklist_item_fixture()

      update_attrs = %{
        active: false,
        position: 43,
        description: "some updated description",
        title: "some updated title",
        required: false
      }

      assert {:ok, %ChecklistItem{} = checklist_item} =
               Checklists.update_checklist_item(checklist_item, update_attrs)

      assert checklist_item.active == false
      assert checklist_item.position == 43
      assert checklist_item.description == "some updated description"
      assert checklist_item.title == "some updated title"
      assert checklist_item.required == false
    end

    test "update_checklist_item/2 with invalid data returns error changeset" do
      checklist_item = checklist_item_fixture()

      assert {:error, %Ecto.Changeset{}} =
               Checklists.update_checklist_item(checklist_item, @invalid_attrs)

      assert checklist_item == Checklists.get_checklist_item!(checklist_item.id)
    end

    test "delete_checklist_item/1 deletes the checklist_item" do
      checklist_item = checklist_item_fixture()
      assert {:ok, %ChecklistItem{}} = Checklists.delete_checklist_item(checklist_item)

      assert_raise Ecto.NoResultsError, fn ->
        Checklists.get_checklist_item!(checklist_item.id)
      end
    end

    test "change_checklist_item/1 returns a checklist_item changeset" do
      checklist_item = checklist_item_fixture()
      assert %Ecto.Changeset{} = Checklists.change_checklist_item(checklist_item)
    end
  end
end
