class LeaveRequestApprovedNotification < ApplicationNotification
  key      :leave_request_approved
  category :operational
  owner    :people_team
  recipient :employee

  param :employee,      required: true
  param :starts_on,     required: true   # Date
  param :ends_on,       required: true   # Date
  param :approver_name, required: true

  dedupe_by { |p| [ p.employee.id, p.starts_on, p.ends_on ] }

  content do |p|
    title  t(".title")
    body   t(".body", starts_on: I18n.l(p.starts_on, format: :long),
                      ends_on: I18n.l(p.ends_on, format: :long), approver: p.approver_name)
    action t(".action"), url: routes.root_url
  end

  preview do
    { employee: Employee.first, starts_on: Date.current + 7, ends_on: Date.current + 14, approver_name: "Paula Fuentes" }
  end
end
