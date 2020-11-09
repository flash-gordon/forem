module Sidekiq
  class HoneycombMiddleware
    include ::Dry::Effects.Resolve(:tracing)

    # @param [Object] worker the worker instance
    # @param [Hash] job the full job payload
    #   * @see https://github.com/mperham/sidekiq/wiki/Job-Format
    # @param [String] queue the name of the queue the job was pulled from
    def call(worker, job, queue)
      tracing.start_span(name: "sidekiq") do |span|
        span.add_field("sidekiq.class", worker.class.name)
        span.add_field("sidekiq.queue", queue)
        span.add_field("sidekiq.jid", job["jid"])
        span.add_field("sidekiq.args", job["args"])
        span.add_field("sidekiq.retry", job["retry"])
        span.add_field("sidekiq.retry_count", job["retry_count"])
        begin
          yield
          span.add_field("sidekiq.result", "success")
        rescue StandardError => e
          span.add_field("sidekiq.result", "error")
          span.add_field("sidekiq.error", e.message)
          raise e
        end
      end
    end
  end
end
