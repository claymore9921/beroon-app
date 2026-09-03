defmodule Beroon.OperationsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Beroon.Operations` context.
  """

  @doc """
  Generate a branch.
  """
  def branch_fixture(attrs \\ %{}) do
    {:ok, branch} =
      attrs
      |> Enum.into(%{
        active: true,
        code: "some code",
        manager_name: "some manager_name",
        name: "some name"
      })
      |> Beroon.Operations.create_branch()

    branch
  end
end
