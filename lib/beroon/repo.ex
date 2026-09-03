defmodule Beroon.Repo do
  use Ecto.Repo,
    otp_app: :beroon,
    adapter: Ecto.Adapters.Postgres
end
