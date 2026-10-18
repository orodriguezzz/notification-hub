require "rubocop"

module RuboCop
  module Cop
    module Notifications
      # Los controladores no envían notificaciones: llaman a un servicio de dominio,
      # que hace el cambio de negocio y el deliver en la misma transacción.
      #
      #   # mal (en app/controllers)
      #   LeaveRequestApprovedNotification.deliver(to: employee, params: { ... })
      #
      #   # bien
      #   Leave::ApproveRequest.call(leave_request: leave_request, approver: current_user)
      class NoDeliverInControllers < Base
        MSG = "No llames a `%<method>s` de una notificación desde un controlador: usa un servicio de dominio."
        RESTRICT_ON_SEND = %i[deliver deliver_many sent].freeze

        def on_send(node)
          receiver = node.receiver
          return unless receiver&.const_type?
          return unless receiver.short_name.to_s.end_with?("Notification")

          add_offense(node, message: format(MSG, method: node.method_name))
        end
        alias on_csend on_send
      end
    end
  end
end
