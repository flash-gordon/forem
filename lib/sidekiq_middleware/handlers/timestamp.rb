require 'dry/effects'

module SidekiqMiddleware
  module Handlers
    class Timestamp
      include ::Dry::Effects::Handler.Timestamp

      def call(_worker, _job, _queue, &block)
        with_timestamp(overridable: overridable?, &block)
      end

      def overridable?
        ::Rails.env.test?
      end
    end
  end
end
