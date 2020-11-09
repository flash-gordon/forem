require "rails_helper"

RSpec.describe Sidekiq::HoneycombMiddleware do
  let(:failing_worker) do
    Class.new do
        include Sidekiq::Worker
      sidekiq_options queue: :low_priority

      def perform(arg = nil)
        raise StandardError, "BOOM" if arg == "fail"
      end
    end
  end

  before do
    stub_const('TestSidekiqWorker', failing_worker)
  end

  let(:expected_hash) do
    {
      "sidekiq.class" => TestSidekiqWorker.to_s,
      "sidekiq.queue" => "low_priority",
      "sidekiq.jid" => instance_of(String),
      "sidekiq.args" => ["dont fail"],
      "sidekiq.result" => "success"
    }
  end

  let(:captured_args) do
    tracing_backend.fields.transform_values(&:first)
  end

  before do
    Sidekiq::Testing.server_middleware do |chain|
      chain.add described_class
    end
  end

  it "sends an event with expected keys" do
    Sidekiq::Testing.inline! do
      TestSidekiqWorker.perform_async("dont fail")
    end

    expect(captured_args).to include(expected_hash)
  end

  context "without args" do
    let(:expected_hash) do
      {
        "sidekiq.class" => TestSidekiqWorker.to_s,
        "sidekiq.queue" => "low_priority",
        "sidekiq.jid" => instance_of(String),
        "sidekiq.args" => [],
        "sidekiq.result" => "success"
      }
    end

    it "sends an event with expected keys" do
      Sidekiq::Testing.inline! do
        TestSidekiqWorker.perform_async
      end

      expect(tracing_backend.spans).to eql(%w(sidekiq))
      expect(captured_args).to include(expected_hash)
    end
  end

  context "with an error" do
    let(:error_hash) do
      {
        "sidekiq.class" => TestSidekiqWorker.to_s,
        "sidekiq.queue" => "low_priority",
        "sidekiq.jid" => instance_of(String),
        "sidekiq.args" => ["fail"],
        "sidekiq.error" => "BOOM",
        "sidekiq.result" => "error"
      }
    end

    it "sends an event with expected keys" do
      Sidekiq::Testing.inline! do
        expect { TestSidekiqWorker.perform_async("fail") }.to raise_error(StandardError)
      end

      expect(captured_args).to include(error_hash)
    end
  end
end
