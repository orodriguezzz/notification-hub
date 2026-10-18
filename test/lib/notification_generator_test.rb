require "test_helper"
require "rails/generators/test_case"
require Rails.root.join("lib/generators/notification/notification_generator")

class NotificationGeneratorTest < Rails::Generators::TestCase
  tests NotificationGenerator
  destination Rails.root.join("tmp/generators")

  setup do
    prepare_destination
    FileUtils.mkdir_p(File.join(destination_root, "config/locales"))
    File.write(File.join(destination_root, NotificationGenerator::LOCALE_FILE), "es:\n  notifications:\n    birthday:\n      name: x\n")
  end

  test "crea la clase, las claves I18n y el test" do
    run_generator %w[SurveyClosed --category=engagement --owner=people_team]

    assert_file "app/notifications/survey_closed_notification.rb" do |content|
      assert_match "class SurveyClosedNotification < ApplicationNotification", content
      assert_match "key      :survey_closed", content
      assert_match "category :engagement", content
      assert_match "owner    :people_team", content
    end
    assert_file NotificationGenerator::LOCALE_FILE do |content|
      locale = YAML.safe_load(content)
      assert_equal "Survey closed", locale.dig("es", "notifications", "survey_closed", "name")
      assert locale.dig("es", "notifications", "birthday")
    end
    assert_file "test/notifications/survey_closed_notification_test.rb", /SurveyClosedNotificationTest/
  end

  test "rechaza una categoría inválida" do
    output = capture(:stderr) { run_generator %w[Promo --category=marketing --owner=growth] }

    assert_match "Categoría inválida", output
    assert_no_file "app/notifications/promo_notification.rb"
  end
end
