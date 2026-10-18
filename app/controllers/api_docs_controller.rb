# Modo demo: Swagger UI para revisar los endpoints HTTP (docs/openapi.yaml)
class ApiDocsController < ApplicationController
  SPEC_PATH = Rails.root.join("docs/openapi.yaml")

  def show
    render layout: false
  end

  def spec
    send_file SPEC_PATH, type: "application/yaml", disposition: "inline"
  end
end
