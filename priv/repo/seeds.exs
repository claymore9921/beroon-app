alias Beroon.Checklists
alias Beroon.Fleet
alias Beroon.Operations

branches = [
  %{
    name: "شعبه مرکزی",
    code: "BR-01",
    manager_name: "مدیر مرکزی",
    manager_phone: "09120000000",
    active: true
  },
  %{name: "شعبه شمال", code: "BR-02", manager_name: "مدیر شمال", active: true},
  %{name: "شعبه غرب", code: "BR-03", manager_name: "مدیر غرب", active: true}
]

created_branches =
  Enum.map(branches, fn attrs ->
    case Operations.create_branch(attrs) do
      {:ok, branch} -> branch
      {:error, _changeset} -> Enum.find(Operations.list_branches(), &(&1.code == attrs.code))
    end
  end)

device_types =
  [
    %{
      device_identifier: "1n1",
      category: "دوچرخه برقی",
      device_model: "H1",
      description: "دوچرخه برقی روزانه",
      active: true
    },
    %{
      device_identifier: "2n1",
      category: "اسکوتر برقی",
      device_model: "Pro",
      description: "اسکوتر برقی پرقدرت",
      active: true
    }
  ]
  |> Enum.map(fn attrs ->
    case Fleet.create_device_type(attrs) do
      {:ok, device_type} ->
        device_type

      {:error, _changeset} ->
        Enum.find(Fleet.list_device_types(), &(&1.device_identifier == attrs.device_identifier))
    end
  end)

[
  %{
    title: "ترمز و دسته گاز",
    description: "ترمز، دسته گاز و واکنش اولیه بررسی شود.",
    required: true,
    position: 1,
    active: true
  },
  %{
    title: "باتری و شارژ",
    description: "سطح شارژ و سلامت ظاهری باتری ثبت شود.",
    required: true,
    position: 2,
    active: true
  },
  %{
    title: "لاستیک و بدنه",
    description: "لاستیک، چراغ، بدنه و آسیب ظاهری بررسی شود.",
    required: true,
    position: 3,
    active: true
  }
]
|> Enum.each(fn attrs ->
  Checklists.create_checklist_item(attrs)
end)

sample_device_type = Enum.find(device_types, & &1)

created_branches
|> Enum.filter(& &1)
|> Enum.take(2)
|> Enum.with_index(1)
|> Enum.each(fn {branch, index} ->
  Fleet.create_scooter(%{
    branch_id: branch.id,
    device_type_id: sample_device_type.id,
    plate: "BRN-#{index}01",
    barcode: "BRN#{index}01",
    model: "H1",
    status: "active",
    notes: "نمونه برای تست"
  })
end)
