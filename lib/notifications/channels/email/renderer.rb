module Notifications
  module Channels
    module Email
      # Produce asunto, HTML (layout con título, cuerpo y botón de acción) y texto plano.
      # Layouts en app/views/notifications/email/layouts/.
      class Renderer < BaseRenderer
        Message = Data.define(:subject, :html, :text)

        DEFAULT_LAYOUT = :default

        def self.allowed_overrides = %i[layout subject]

        def render(content:, overrides:, recipient:, locale:)
          subject = overrides[:subject].presence || content.title

          I18n.with_locale(locale) do
            html = render_layout(overrides.fetch(:layout, DEFAULT_LAYOUT),
                                 content: content, recipient: recipient, subject: subject)
            Message.new(subject: subject, html: html, text: text_for(content))
          end
        end

        # Correo resumen (digest) con varias notificaciones engagement postergadas
        def render_digest(contents:, recipient:, locale:)
          I18n.with_locale(locale) do
            subject = I18n.t("notifications.digest.subject", count: contents.size)
            html = render_layout(:digest, contents: contents, recipient: recipient, subject: subject)
            text = ([ I18n.t("notifications.digest.intro") ] + contents.map { text_for(_1) }).join("\n\n---\n\n")
            Message.new(subject: subject, html: html, text: text)
          end
        end

        private

        def render_layout(layout, **locals)
          ApplicationController.render(template: "notifications/email/layouts/#{layout}", layout: false, locals: locals)
        end

        def text_for(content)
          parts = [ content.title, content.body ]
          parts << "#{content.action_label}: #{content.action_url}" if content.action?
          parts.join("\n\n")
        end
      end
    end
  end
end
