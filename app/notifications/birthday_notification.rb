class BirthdayNotification < ApplicationNotification
  key      :birthday
  category :engagement
  owner    :people_team
  recipient :employee

  param :employee, required: true
  param :company,  required: true

  cooldown   1.day
  expires_in 2.days
  # Un saludo por colaborador y día, aunque el job corra dos veces
  dedupe_by { |p| [ p.employee.id, Date.current ] }

  content do |p|
    title  t(".title", name: p.employee.first_name)
    body   t(".body", company: p.company.name)
    action t(".action"), url: routes.root_url
  end

  email do |p|
    layout :celebration
  end

  preview { { employee: Employee.first, company: Company.first } }
end
