class PayslipAvailableNotification < ApplicationNotification
  key      :payslip_available
  category :operational
  owner    :payroll_team
  recipient :employee

  param :employee, required: true
  param :period,   required: true   # Date: primer día del mes

  dedupe_by { |p| [ p.employee.id, p.period ] }

  content do |p|
    period = I18n.l(p.period, format: :month_year)
    title  t(".title", period: period)
    body   t(".body", period: period)
    action t(".action"), url: routes.root_url
  end

  preview { { employee: Employee.first, period: Date.current.prev_month.beginning_of_month } }
end
