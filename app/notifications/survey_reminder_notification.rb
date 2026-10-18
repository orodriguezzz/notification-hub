class SurveyReminderNotification < ApplicationNotification
  key      :survey_reminder
  category :engagement
  owner    :people_team
  recipient :employee

  param :employee,     required: true
  param :survey_title, required: true

  # No repetir el recordatorio al mismo colaborador antes de 3 días
  cooldown   3.days
  # Si se posterga más de 2 días, ya no tiene sentido enviarlo
  expires_in 2.days

  content do |p|
    title  t(".title", survey: p.survey_title)
    body   t(".body", name: p.employee.first_name)
    action t(".action"), url: routes.root_url
  end

  preview { { employee: Employee.first, survey_title: "Clima laboral 2026" } }
end
