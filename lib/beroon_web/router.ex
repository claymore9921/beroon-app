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
    get "/manager/notifications", PageController, :manager_notifications
    get "/manager/notifications/:id", PageController, :manager_notification_detail
    get "/manager/scan", PageController, :manager_scan
    get "/manager/scooters", PageController, :manager_scooters
    get "/manager/scooters/:status", PageController, :manager_scooters
    get "/manager/unhealthy-scooters", PageController, :manager_unhealthy_scooters
    get "/manager/transports", PageController, :manager_transports
    post "/manager/transports", PageController, :create_manager_transport
    get "/manager/repairs", PageController, :manager_repairs
    post "/manager/repairs/:id/send", PageController, :send_scooter_to_workshop
    get "/manager/repairs/receive", PageController, :manager_repair_receive
    post "/manager/repairs/receive", PageController, :receive_repaired_scooter
    get "/manager/morning", PageController, :manager_morning
    post "/manager/morning", PageController, :submit_morning
    get "/manager/evening", PageController, :manager_evening
    post "/manager/evening", PageController, :submit_evening

    get "/workshop", PageController, :workshop_home
    get "/workshop/info", PageController, :workshop_info
    get "/workshop/acceptance", PageController, :workshop_acceptance
    get "/workshop/repairing", PageController, :workshop_repairing
    get "/workshop/discharge", PageController, :workshop_discharge
    post "/workshop/scooters/:id/accept", PageController, :workshop_accept_scooter
    post "/workshop/scooters/:id/start", PageController, :workshop_start_repair
    post "/workshop/scooters/:id/waiting-part", PageController, :workshop_waiting_part
    post "/workshop/scooters/:id/discharge", PageController, :workshop_discharge_scooter
  end

  scope "/", BeroonWeb do
    pipe_through [:browser, :require_admin]

    get "/admin/reports", PageController, :admin_reports
    get "/admin/unscanned-devices", PageController, :admin_stale_unscanned_scooters
    get "/admin/notifications", PageController, :admin_notifications
    post "/admin/notifications", PageController, :send_admin_notification
    get "/admin/location-alerts", PageController, :admin_location_alerts
    get "/admin/device-locations", PageController, :admin_device_locations
    get "/admin/managers", PageController, :admin_manager_registrations
    post "/admin/managers/:id/approve", PageController, :approve_manager_registration
    get "/admin/checklists", PageController, :admin_checklist_branches
    get "/admin/checklists/branches/:id", PageController, :admin_branch_checklists
    get "/admin/report-export", PageController, :admin_report_export
    get "/admin/new-device-inventory", PageController, :admin_new_device_inventory
    post "/admin/new-device-inventory/stocks", PageController, :update_new_device_stock
    get "/admin/new-device-sales", PageController, :admin_new_device_sales
    post "/admin/new-device-sales", PageController, :create_new_device_sale
    get "/admin/report-export/download", PageController, :download_admin_report_export
    get "/admin/evening-reports", PageController, :admin_evening_report_branches
    get "/admin/evening-reports/counts/:id", PageController, :admin_evening_report_detail
    get "/admin/evening-reports/branches/:id", PageController, :admin_branch_evening_reports

    get "/admin/checklists/branches/:id/unchecked",
        PageController,
        :admin_branch_unchecked_scooters

    resources "/branches", BranchController
    put "/scooters/:id/status", ScooterController, :update_status
    post "/scooters/import", ScooterController, :import
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
