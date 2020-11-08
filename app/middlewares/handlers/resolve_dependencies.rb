require 'dry/effects'

module Handlers
  class ResolveDependencies
    include ::Dry::Effects::Handler.Resolve

    def initialize(app)
      @app = app
    end

    def call(env)
      provide(::PracticalDeveloper::Container, overridable: overridable?) do
        @app.(env)
      end
    end

    def overridable?
      Rails.env.test?
    end
  end
end
