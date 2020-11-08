class Tracing
  attr_reader :backend

  def initialize(backend)
    @backend = backend
  end

  def start_span(name:, &block)
    @backend.start_span(name: name, &block)
  end

  def add_field(key, value)
    @backend.add_field(key, value)
  end
end
