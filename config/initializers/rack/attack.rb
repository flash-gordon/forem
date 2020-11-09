require 'dry/effects'

Rack::Attack.throttled_response_retry_after_header = true

module Rack
  class Attack
    extend ::Dry::Effects.Resolve(:tracing)

    throttle("search_throttle", limit: 5, period: 1) do |request|
      if request.path.starts_with?("/search/")
        track_and_return_ip(request.env["HTTP_FASTLY_CLIENT_IP"])
      end
    end

    throttle("api_throttle", limit: 3, period: 1) do |request|
      if request.path.starts_with?("/api/") && request.get?
        track_and_return_ip(request.env["HTTP_FASTLY_CLIENT_IP"])
      end
    end

    throttle("api_write_throttle", limit: 1, period: 1) do |request|
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

    throttle("site_hits", limit: 40, period: 2) do |request|
      track_and_return_ip(request.env["HTTP_FASTLY_CLIENT_IP"])
    end

    throttle("message_throttle", limit: 2, period: 1) do |request|
      if request.path.starts_with?("/messages") && request.post?
        track_and_return_ip(request.env["HTTP_FASTLY_CLIENT_IP"])
      end
    end

    def self.track_and_return_ip(ip_address)
      return if ip_address.blank?

      tracing.add_field("fastly_client_ip", ip_address)
      ip_address.to_s
    end
  end
end
