require "rails_helper"

RSpec.describe Rack::Attack, type: :request, throttle: true do
  include Dry::Effects::Handler.Timestamp

  before(:all) do
    Rack::Attack::Cache.prepend(Module.new {
      include Dry::Effects.Timestamp

      def key_and_expiry(unprefixed_key, period)
        @last_epoch_time = timestamp.to_i
        # Add 1 to expires_in to avoid timing error: https://git.io/i1PHXA
        expires_in = (period - (@last_epoch_time % period) + 1).to_i
        ["#{prefix}:#{(@last_epoch_time / period).to_i}:#{unprefixed_key}", expires_in]
      end
    })
  end

  around do
    now = Time.now
    with_timestamp(-> { now }, &_1)
  end

  before do
    cache_db = ActiveSupport::Cache.lookup_store(:redis_cache_store)
    allow(Rails).to receive(:cache) { cache_db }
    cache_db.redis.flushdb
  end

  describe "search_throttle" do
    it "throttles /search endpoints based on IP" do
      allow(Search::User).to receive(:search_documents).and_return({})
      valid_responses = Array.new(5).map do
        get "/search/users", headers: { "HTTP_FASTLY_CLIENT_IP" => "5.6.7.8" }
      end
      throttled_response = get "/search/users", headers: { "HTTP_FASTLY_CLIENT_IP" => "5.6.7.8" }
      new_ip_response = get "/search/users", headers: { "HTTP_FASTLY_CLIENT_IP" => "1.1.1.1" }

      valid_responses.each { |r| expect(r).not_to eq(429) }
      expect(throttled_response).to eq(429)
      expect(new_ip_response).not_to eq(429)
      expect(tracing_backend.fields['fastly_client_ip']).to eql(
        ["5.6.7.8"] * 11 + ["1.1.1.1"] * 2
      )
    end
  end

  describe "api_throttle" do
    it "throttles api get endpoints based on IP" do
      Timecop.freeze do
        valid_responses = Array.new(3).map do
          get api_articles_path, headers: { "HTTP_FASTLY_CLIENT_IP" => "5.6.7.8" }
        end
        throttled_response = get api_articles_path, headers: { "HTTP_FASTLY_CLIENT_IP" => "5.6.7.8" }
        new_ip_response = get api_articles_path, headers: { "HTTP_FASTLY_CLIENT_IP" => "1.1.1.1" }

        valid_responses.each { |r| expect(r).not_to eq(429) }
        expect(throttled_response).to eq(429)
        expect(new_ip_response).not_to eq(429)
        expect(tracing_backend.fields['fastly_client_ip']).to eql(
          ["5.6.7.8"] * 7 + ["1.1.1.1"] * 2
        )
      end
    end
  end

  describe "api_write_throttle" do
    let(:api_secret) { create(:api_secret) }
    let(:another_api_secret) { create(:api_secret) }
    let(:headers) do
      { "api-key" => api_secret.secret, "content-type" => "application/json", "HTTP_FASTLY_CLIENT_IP" => "5.6.7.8" }
    end
    let(:dif_headers) do
      {
        "api-key" => another_api_secret.secret,
        "content-type" => "application/json",
        "HTTP_FASTLY_CLIENT_IP" => "5.6.7.8"
      }
    end

    it "throttles api write endpoints based on IP and API key" do
      params = { article: { body_markdown: "", title: Faker::Book.title } }.to_json

      valid_response = post api_articles_path, params: params, headers: headers
      throttled_response = post api_articles_path, params: params, headers: headers
      new_api_response = post api_articles_path, params: params, headers: dif_headers

      expect(valid_response).not_to eq(429)
      expect(throttled_response).to eq(429)
      expect(new_api_response).not_to eq(429)
      expect(tracing_backend.fields).to include(
        'fastly_client_ip' => ["5.6.7.8"] * 5,
        'user_api_key' => [
          api_secret.secret, api_secret.secret, another_api_secret.secret
        ]
      )
    end

    it "throttles api write endpoints based on IP if API key not present" do
      headers = { "content-type" => "application/json", "HTTP_FASTLY_CLIENT_IP" => "5.6.7.8" }
      dif_headers = { "content-type" => "application/json", "HTTP_FASTLY_CLIENT_IP" => "1.1.1.1" }
      params = { article: { body_markdown: "", title: Faker::Book.title } }.to_json

      valid_response = post api_articles_path, params: params, headers: headers
      throttled_response = post api_articles_path, params: params, headers: headers
      new_api_response = post api_articles_path, params: params, headers: dif_headers

      expect(valid_response).not_to eq(429)
      expect(throttled_response).to eq(429)
      expect(new_api_response).not_to eq(429)
      expect(tracing_backend.fields['fastly_client_ip']).to eql(
        ["5.6.7.8"] * 3 + ["1.1.1.1"] * 2
      )
    end
  end

  describe "message_throttle" do
    let(:user) { create(:user) }
    let(:chat_channel) { create(:chat_channel) }
    let(:new_message) do
      {
        message_markdown: "hi",
        user_id: user.id,
        temp_id: "sd78jdssd",
        chat_channel_id: chat_channel.id
      }
    end

    before do
      allow(Pusher).to receive(:trigger).and_return(true)
      sign_in user
    end

    it "throttles creating messages" do
      headers = { "HTTP_FASTLY_CLIENT_IP" => "5.6.7.8" }
      dif_headers = { "HTTP_FASTLY_CLIENT_IP" => "1.1.1.1" }

      valid_responses = Array.new(2).map do
        post messages_path, params: { message: new_message }, headers: headers
      end
      throttled_response = post messages_path, params: { message: new_message }, headers: headers
      new_api_response = post messages_path, params: { message: new_message }, headers: dif_headers

      valid_responses.each { |r| expect(r).not_to eq(429) }
      expect(throttled_response).to eq(429)
      expect(new_api_response).not_to eq(429)
      expect(tracing_backend.fields['fastly_client_ip']).to eql(
        ["5.6.7.8"] * 6 + ["1.1.1.1"] * 2
      )
    end
  end
end
