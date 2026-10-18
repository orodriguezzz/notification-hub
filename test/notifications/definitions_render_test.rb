require "test_helper"

# CI: todas las definiciones del registro renderizan en todos los canales registrados con su preview
class Notifications::DefinitionsRenderTest < ActiveSupport::TestCase
  test "el registro contiene las cinco definiciones requeridas" do
    assert_empty %w[birthday leave_request_approved payslip_available signed_document_copy survey_reminder] -
                 Notifications::Registry.keys
  end

  # Solo las definiciones de la app (los tests pueden registrar definiciones propias)
  app_definitions = Notifications::Registry.all.select do |definition|
    Object.const_source_location(definition.name).first.include?("/app/notifications/")
  end

  app_definitions.each do |definition|
    Notifications::Channels::Registry.entries.each do |channel|
      test "#{definition.name} renderiza en #{channel.name}" do
        params = definition.preview_params
        recipient = params.fetch(definition.recipient)
        normalized = definition.normalize_params(recipient, params)

        content = definition.build_content(normalized)
        assert_kind_of Notifications::Content, content
        assert content.frozen?, "el contenido debe ser inmutable"
        assert content.title.present?
        assert content.body.present?

        overrides = definition.overrides_for(channel.name, normalized, allowed: channel.renderer_class.allowed_overrides)
        message = channel.renderer.render(content: content, overrides: overrides, recipient: recipient, locale: :es)

        assert message.text.present?
        assert_includes message.text, content.title
        if message.respond_to?(:html)
          assert_includes message.html, ERB::Util.html_escape(content.body)
          assert_includes message.html, content.action_url if content.action?
        end
      end
    end

    test "#{definition.name} tiene nombre legible para el historial" do
      assert I18n.exists?("notifications.#{definition.notification_key}.name", :es)
    end
  end
end
