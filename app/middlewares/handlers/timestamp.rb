require 'dry/effects'

module Handlers
  class Timestamp
    include ::Dry::Effects::Handler.Timestamp

    def initialize(app)
      @app = app
    end

    def call(env)
      with_timestamp(overridable: overridable?) { @app.(env) }
    end

    def overridable?
      ::Rails.env.test?
    end
  end
end
