defmodule BeroonWeb.Router do
  use BeroonWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {BeroonWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug BeroonWeb.AdminAuth, :fetch_current_user
  end

  pipeline :require_authenticated do
    plug BeroonWeb.AdminAuth, :require_authenticated
  end

  pipeline :require_admin do
    plug BeroonWeb.AdminAuth, :require_admin
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", BeroonWeb do
    pipe_through :browser

    get "/", PageController, :home
    get "/login", AdminSessionController, :new
    post "/login", AdminSessionController, :create
    get "/verify", AdminSessionController, :verify
    post "/verify", AdminSessionController, :confirm
    delete "/logout", AdminSessionController, :delete

    get "/admin/login", AdminSessionController, :new
    post "/admin/login", AdminSessionController, :create
    get "/admin/verify", AdminSessionController, :verify
    post "/admin/verify", AdminSessionController, :confirm
    delete "/admin/logout", AdminSessionController, :delete
  end

  scope "/api", BeroonWeb do
    pipe_through [:browser, :require_authenticated]

    get "/scooters/lookup", ScooterLookupController, :show
  end

  scope "/", BeroonWeb do
    pipe_through [:browser, :require_authenticated]

    get "/manager", PageController, :manager_home
    get "/manager/pending", PageController, :manager_pending
    get "/manager/scooters", PageController, :manager_scooters
    get "/manager/scooters/:status", PageController, :manager_scooters
    get "/manager/morning", PageController, :manager_morning
    post "/manager/morning", PageController, :submit_morning
    get "/manager/evening", PageController, :manager_evening
    post "/manager/evening", PageController, :submit_evening
  end

  scope "/", BeroonWeb do
    pipe_through [:browser, :require_admin]

    get "/admin/reports", PageController, :admin_reports
    get "/admin/location-alerts", PageController, :admin_location_alerts
    get "/admin/managers", PageController, :admin_manager_registrations
    post "/admin/managers/:id/approve", PageController, :approve_manager_registration
    get "/admin/checklists", PageController, :admin_checklist_branches
    get "/admin/checklists/branches/:id", PageController, :admin_branch_checklists
    get "/admin/evening-reports", PageController, :admin_evening_report_branches
    get "/admin/evening-reports/counts/:id", PageController, :admin_evening_report_detail
    get "/admin/evening-reports/branches/:id", PageController, :admin_branch_evening_reports

    get "/admin/checklists/branches/:id/unchecked",
        PageController,
        :admin_branch_unchecked_scooters

    resources "/branches", BranchController
    resources "/scooters", ScooterController
    resources "/device_types", DeviceTypeController
    resources "/checklist_items", ChecklistItemController
    resources "/morning_inspections", MorningInspectionController
    resources "/evening_counts", EveningCountController
  end

  if Application.compile_env(:beroon, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: BeroonWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
