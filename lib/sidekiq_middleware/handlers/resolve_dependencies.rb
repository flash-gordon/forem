require 'dry/effects'

module SidekiqMiddleware
  module Handlers
    class ResolveDependencies
      include ::Dry::Effects::Handler.Resolve

      def call(_worker, _job, _queue, &block)
        provide(::PracticalDeveloper::Container, overridable: overridable?, &block)
      end

      def overridable?
        Rails.env.test?
      end
    end
  end
end
