require 'dry/effects'

module Handlers
  class ResolveDependencies
    include ::Dry::Effects::Handler.Resolve

    def initialize(app)
      @app = app
    end

    def call(env)
      provide(::PracticalDeveloper::Container) { @app.(env) }
    end
  end
end
