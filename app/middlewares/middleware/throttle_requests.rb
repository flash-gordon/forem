require 'dry/effects'
require 'rack/attack'

module Middleware
  class ThrottleRequests < ::Rack::Attack
    class Cache < superclass::Cache
      include ::Dry::Effects.Timestamp

      private

      def key_and_expiry(unprefixed_key, period)
        @last_epoch_time = timestamp.to_i
        # Add 1 to expires_in to avoid timing error: https://git.io/i1PHXA
        expires_in = (period - (@last_epoch_time % period) + 1).to_i
        ["#{prefix}:#{(@last_epoch_time / period).to_i}:#{unprefixed_key}", expires_in]
      end
    end

    extend ::Dry::Effects.Reader(:throttle_requests, as: :enabled, default: true)
    include ::Dry::Effects.Resolve(:tracing)
    include ::Dry::Effects.Reader(:throttling_cache)
    include ::Dry::Effects::Handler.Reader(:throttling_cache)

    self.notifier = superclass.notifier

    def initialize(app)
      super(app)

      @cache = Cache.new
      @configuration = Configuration.new

      configuration.throttled_response_retry_after_header = true

      add_limits
      configuration.throttles.each_value do
        _1.extend(::Dry::Effects.Reader(:throttling_cache, as: :cache))
      end
    end

    def call(*)
      with_throttling_cache(throttling_cache { @cache }) { super }
    end

    def track_and_return_ip(ip_address)
      return if ip_address.blank?

      tracing.add_field("fastly_client_ip", ip_address)
      ip_address.to_s
    end

    def add_limits
      configuration.throttle("search_throttle", limit: 5, period: 1) do |request|
        if request.path.starts_with?("/search/")
          track_and_return_ip(request.env["HTTP_FASTLY_CLIENT_IP"])
        end
      end

      configuration.throttle("api_throttle", limit: 3, period: 1) do |request|
        if request.path.starts_with?("/api/") && request.get?
          track_and_return_ip(request.env["HTTP_FASTLY_CLIENT_IP"])
        end
      end

      configuration.throttle("api_write_throttle", limit: 1, period: 1) do |request|
        if request.path.starts_with?("/api/") && (request.put? || request.post? || request.delete?)
          tracing.add_field("user_api_key", request.env["HTTP_API_KEY"])
          ip_address = track_and_return_ip(request.env["HTTP_FASTLY_CLIENT_IP"])
          if request.env["HTTP_API_KEY"].present?
            "#{ip_address}-#{request.env['HTTP_API_KEY']}"
          elsif ip_address.present?
            ip_address
          end
        end
      end

      configuration.throttle("site_hits", limit: 40, period: 2) do |request|
        track_and_return_ip(request.env["HTTP_FASTLY_CLIENT_IP"])
      end

      configuration.throttle("message_throttle", limit: 2, period: 1) do |request|
        if request.path.starts_with?("/messages") && request.post?
          track_and_return_ip(request.env["HTTP_FASTLY_CLIENT_IP"])
        end
      end
    end
  end
end
