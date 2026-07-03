defmodule Beroon.ChecklistsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Beroon.Checklists` context.
  """

  @doc """
  Generate a checklist_item.
  """
  def checklist_item_fixture(attrs \\ %{}) do
    {:ok, checklist_item} =
      attrs
      |> Enum.into(%{
        active: true,
        description: "some description",
        position: 42,
        required: true,
        title: "some title"
      })
      |> Beroon.Checklists.create_checklist_item()

    checklist_item
  end
end
