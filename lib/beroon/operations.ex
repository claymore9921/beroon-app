defmodule Beroon.Operations do
  @moduledoc """
  The Operations context.
  """

  import Ecto.Query, warn: false
  alias Beroon.Repo

  alias Beroon.Operations.Branch
  alias Beroon.Operations.BranchManagerRegistration

  @doc """
  Returns the list of branches.

  ## Examples

      iex> list_branches()
      [%Branch{}, ...]

  """
  def list_branches do
    Branch
    |> order_by([b], asc: b.name)
    |> Repo.all()
  end

  def list_active_branches do
    Branch
    |> where([b], b.active == true)
    |> order_by([b], asc: b.name)
    |> Repo.all()
  end

  def get_branch_for_manager_phone(phone) when is_binary(phone) do
    normalized_phone = String.trim(phone)

    Branch
    |> where([b], b.manager_phone == ^normalized_phone and b.active == true)
    |> order_by([b], asc: b.name)
    |> Repo.one()
  end

  def get_branch_for_manager_phone(_phone), do: nil

  def ensure_manager_registration(phone) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    normalized_phone = normalize_phone(phone)

    %BranchManagerRegistration{}
    |> BranchManagerRegistration.changeset(%{
      phone: normalized_phone,
      status: "pending",
      requested_at: now
    })
    |> Repo.insert(
      on_conflict: [set: [requested_at: now, updated_at: now]],
      conflict_target: :phone
    )
  end

  def list_pending_manager_registrations do
    BranchManagerRegistration
    |> where([r], r.status == "pending")
    |> order_by([r], desc: r.requested_at)
    |> Repo.all()
  end

  def approve_manager_registration(registration_id, branch_id) do
    registration = Repo.get!(BranchManagerRegistration, registration_id)
    branch = get_branch!(branch_id)
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    Repo.transaction(fn ->
      {:ok, updated_branch} =
        branch
        |> Branch.changeset(%{manager_phone: registration.phone})
        |> Repo.update()

      {:ok, updated_registration} =
        registration
        |> BranchManagerRegistration.changeset(%{
          status: "approved",
          branch_id: updated_branch.id,
          approved_at: now
        })
        |> Repo.update()

      updated_registration
    end)
  end

  defp normalize_phone(phone) do
    phone
    |> to_string()
    |> String.trim()
    |> String.replace(~r/[^\d+]/, "")
    |> case do
      "+98" <> rest -> "0" <> rest
      "98" <> rest when byte_size(rest) == 10 -> "0" <> rest
      other -> other
    end
  end

  @doc """
  Gets a single branch.

  Raises `Ecto.NoResultsError` if the Branch does not exist.

  ## Examples

      iex> get_branch!(123)
      %Branch{}

      iex> get_branch!(456)
      ** (Ecto.NoResultsError)

  """
  def get_branch!(id), do: Repo.get!(Branch, id)

  @doc """
  Creates a branch.

  ## Examples

      iex> create_branch(%{field: value})
      {:ok, %Branch{}}

      iex> create_branch(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_branch(attrs) do
    %Branch{}
    |> Branch.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a branch.

  ## Examples

      iex> update_branch(branch, %{field: new_value})
      {:ok, %Branch{}}

      iex> update_branch(branch, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_branch(%Branch{} = branch, attrs) do
    branch
    |> Branch.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a branch.

  ## Examples

      iex> delete_branch(branch)
      {:ok, %Branch{}}

      iex> delete_branch(branch)
      {:error, %Ecto.Changeset{}}

  """
  def delete_branch(%Branch{} = branch) do
    Repo.delete(branch)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking branch changes.

  ## Examples

      iex> change_branch(branch)
      %Ecto.Changeset{data: %Branch{}}

  """
  def change_branch(%Branch{} = branch, attrs \\ %{}) do
    Branch.changeset(branch, attrs)
  end
end
