defmodule Beroon.AuthTest do
  use Beroon.DataCase

  alias Beroon.Auth
  alias Beroon.Auth.OtpChallenge
  alias Beroon.Repo

  test "request_login_otp/1 creates an OTP and resolves pending manager role until approved" do
    assert {:ok, %OtpChallenge{} = challenge} = Auth.request_login_otp("0939 964 4901")
    assert challenge.phone == "09399644901"
    assert Auth.role_for_phone(challenge.phone) == :admin

    assert {:ok, %OtpChallenge{} = manager_challenge} = Auth.request_login_otp("09120000000")
    assert Auth.role_for_phone(manager_challenge.phone) == :branch_manager_pending

    Beroon.OperationsFixtures.branch_fixture(%{
      manager_phone: manager_challenge.phone
    })

    assert Auth.role_for_phone(manager_challenge.phone) == :branch_manager
  end

  test "role_for_phone/1 resolves approved workshop manager" do
    workshop =
      Beroon.OperationsFixtures.branch_fixture(%{
        kind: "workshop",
        manager_phone: "09130000000"
      })

    assert workshop.kind == "workshop"
    assert Auth.role_for_phone("09130000000") == :workshop_manager
  end

  test "verify_login_otp/2 creates pending registration for unapproved manager" do
    assert {:ok, _challenge} = Auth.request_login_otp("09120000000")

    assert {:ok, %{phone: "09120000000", role: :branch_manager_pending}} =
             Auth.verify_login_otp("09120000000", "123456")

    assert [%{phone: "09120000000"}] = Beroon.Operations.list_pending_manager_registrations()
  end

  test "verify_login_otp/2 accepts the latest unexpired code once" do
    assert {:ok, _challenge} = Auth.request_login_otp("+989399644901")

    assert {:ok, %{phone: "09399644901", role: :admin}} =
             Auth.verify_login_otp("09399644901", "123456")

    assert {:error, :expired_or_missing} = Auth.verify_login_otp("09399644901", "123456")
  end

  test "verify_login_otp/2 rejects wrong codes and increments attempts" do
    assert {:ok, challenge} = Auth.request_login_otp("09399644901")
    assert {:error, :invalid_code} = Auth.verify_login_otp("09399644901", "000000")

    assert %{attempts: 1} = Repo.get!(OtpChallenge, challenge.id)
  end
end
