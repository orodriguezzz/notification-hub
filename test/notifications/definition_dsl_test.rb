require "test_helper"

class Notifications::DefinitionDslTest < ActiveSupport::TestCase
  teardown do
    %w[DslMissingNotification DslBadCategoryNotification DslDuplicateNotification DslValidNotification].each do |name|
      Object.send(:remove_const, name) if Object.const_defined?(name, false)
    end
    Notifications::Registry.unregister(:dsl_valid)
  end

  test "falla al cargar la clase si falta un campo obligatorio" do
    error = assert_raises(Notifications::DefinitionError) do
      Object.class_eval <<~RUBY, __FILE__, __LINE__ + 1
        class DslMissingNotification < ApplicationNotification
          key :dsl_missing
          category :engagement
        end
      RUBY
    end

    assert_match "owner", error.message
    assert_match "recipient", error.message
    assert_match "content", error.message
    assert_not Notifications::Registry.registered?(:dsl_missing)
  end

  test "solo acepta las categorías critical, operational y engagement" do
    assert_raises(Notifications::DefinitionError) do
      Object.class_eval <<~RUBY, __FILE__, __LINE__ + 1
        class DslBadCategoryNotification < ApplicationNotification
          key :dsl_bad_category
          category :marketing
        end
      RUBY
    end
  end

  test "una key duplicada en el registro falla al cargar" do
    error = assert_raises(Notifications::DefinitionError) do
      Object.class_eval <<~RUBY, __FILE__, __LINE__ + 1
        class DslDuplicateNotification < ApplicationNotification
          key :birthday
          category :engagement
          owner :people_team
          recipient :employee
          content { |p| title "x"; body "y" }
        end
      RUBY
    end

    assert_match "ya está registrada por BirthdayNotification", error.message
  end

  test "una definición válida queda registrada al cerrar la clase" do
    Object.class_eval <<~RUBY, __FILE__, __LINE__ + 1
      class DslValidNotification < ApplicationNotification
        key :dsl_valid
        category :operational
        owner :platform_team
        recipient :employee
        param :employee, required: true
        content { |p| title "Hola \#{p.employee.first_name}"; body "Cuerpo" }
      end
    RUBY

    assert_equal DslValidNotification, Notifications::Registry.fetch(:dsl_valid)
  end

  test "t('.x') resuelve a notifications.<key>.x" do
    content = BirthdayNotification.build_content({ employee: employees(:ana), company: companies(:acme_cl) })

    assert_equal "¡Feliz cumpleaños, Ana!", content.title
    assert_equal "Todo el equipo de Acme Chile te desea un excelente día.", content.body
    assert_equal "Ver saludos", content.action_label
  end

  test "el contenido es un value object inmutable" do
    content = BirthdayNotification.build_content({ employee: employees(:ana), company: companies(:acme_cl) })

    assert content.frozen?
    assert_raises(NoMethodError) { content.title = "otro" }
  end

  test "los overrides por canal solo refinan presentación" do
    overrides = BirthdayNotification.overrides_for(:email, { employee: employees(:ana) }, allowed: %i[layout subject])
    assert_equal({ layout: :celebration }, overrides)

    error = assert_raises(Notifications::DefinitionError) do
      BirthdayNotification.overrides_for(:email, { employee: employees(:ana) }, allowed: %i[subject])
    end
    assert_match "layout", error.message
  end

  test "las definiciones no mencionan canales ni direcciones" do
    Dir[Rails.root.join("app/notifications/*.rb")].each do |path|
      source = File.read(path)
      assert_no_match(/sendgrid|whatsapp|slack|sms|@\w+\.\w+/i, source, "#{path} no debe mencionar canales")
    end
  end
end
