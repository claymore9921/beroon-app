defmodule Beroon.Catalog do
  import Ecto.Query, warn: false
  alias Beroon.Repo
  alias Beroon.CatalogLead

  def create_lead(attrs), do: %CatalogLead{} |> CatalogLead.changeset(attrs) |> Repo.insert()
  def list_leads do
    CatalogLead |> order_by([l], desc: l.inserted_at) |> Repo.all()
  end
end
