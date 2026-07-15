defmodule Beroon.Auth do
  @moduledoc """
  Phone OTP authentication for Beroon users.
  """

  import Ecto.Query, warn: false
  require Logger

  alias Beroon.Auth.OtpChallenge
  alias Beroon.Operations
  alias Beroon.Repo

  @purpose "login"
  @max_attempts 5

  def admin_phone do
    config() |> Keyword.get(:admin_phone, "09399644901") |> normalize_phone()
  end

  def admin_phone?(phone), do: normalize_phone(phone) == admin_phone()

  def role_for_phone(phone) do
    cond do
      admin_phone?(phone) ->
        :admin

      Operations.get_branch_for_manager_phone(normalize_phone(phone)) ->
        :branch_manager

      Operations.get_workshop_for_manager_phone(normalize_phone(phone)) ->
        :workshop_manager

      true ->
        :branch_manager_pending
    end
  end

  def request_login_otp(phone) do
    phone = normalize_phone(phone)

    code = generate_code()
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    expires_at = DateTime.add(now, otp_ttl_minutes() * 60, :second)

    attrs = %{
      phone: phone,
      code_hash: hash_code(phone, code),
      purpose: @purpose,
      attempts: 0,
      expires_at: expires_at
    }

    %OtpChallenge{}
    |> OtpChallenge.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, challenge} ->
        Logger.info("Beroon OTP for #{phone} (#{role_for_phone(phone)}): #{code}")
        {:ok, challenge}

      error ->
        error
    end
  end

  def request_admin_otp(phone), do: request_login_otp(phone)

  def verify_login_otp(phone, code) do
    phone = normalize_phone(phone)
    code = String.trim(to_string(code || ""))
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    with %OtpChallenge{} = challenge <- latest_open_challenge(phone, now),
         false <- challenge.attempts >= @max_attempts,
         true <- secure_compare(challenge.code_hash, hash_code(phone, code)) do
      challenge
      |> OtpChallenge.changeset(%{consumed_at: now})
      |> Repo.update()

      role = role_for_phone(phone)

      if role == :branch_manager_pending do
        Operations.ensure_manager_registration(phone)
      end

      {:ok, %{phone: phone, role: role}}
    else
      false ->
        increment_attempts(phone, now)
        {:error, :invalid_code}

      nil ->
        {:error, :expired_or_missing}

      true ->
        {:error, :too_many_attempts}
    end
  end

  def verify_admin_otp(phone, code) do
    case verify_login_otp(phone, code) do
      {:ok, %{phone: phone, role: :admin}} -> {:ok, phone}
      {:ok, _user} -> {:error, :unauthorized_phone}
      error -> error
    end
  end

  def normalize_phone(phone) do
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

  defp latest_open_challenge(phone, now) do
    OtpChallenge
    |> where([o], o.phone == ^phone)
    |> where([o], o.purpose == ^@purpose)
    |> where([o], is_nil(o.consumed_at))
    |> where([o], o.expires_at > ^now)
    |> order_by([o], desc: o.inserted_at)
    |> limit(1)
    |> Repo.one()
  end

  defp increment_attempts(phone, now) do
    case latest_open_challenge(phone, now) do
      %OtpChallenge{} = challenge ->
        challenge
        |> OtpChallenge.changeset(%{attempts: challenge.attempts + 1})
        |> Repo.update()

      nil ->
        :ok
    end
  end

  defp generate_code do
    case Keyword.get(config(), :otp_code_override) do
      nil ->
        :crypto.strong_rand_bytes(4)
        |> :binary.decode_unsigned()
        |> rem(1_000_000)
        |> Integer.to_string()
        |> String.pad_leading(6, "0")

      code ->
        code
        |> to_string()
        |> String.pad_leading(6, "0")
    end
  end

  defp hash_code(phone, code) do
    :crypto.hash(:sha256, "#{phone}:#{code}:#{otp_secret()}")
    |> Base.encode16(case: :lower)
  end

  defp secure_compare(left, right) do
    Plug.Crypto.secure_compare(to_string(left), to_string(right))
  rescue
    _ -> false
  end

  defp otp_ttl_minutes, do: Keyword.get(config(), :otp_ttl_minutes, 5)
  defp otp_secret, do: Keyword.get(config(), :otp_secret, "beroon-dev-otp-secret")

  defp config do
    Application.get_env(:beroon, __MODULE__, [])
  end
end
