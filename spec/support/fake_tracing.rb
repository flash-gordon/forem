class FakeTracing
  attr_reader :fields

  attr_reader :spans

  def initialize
    @spans = []
    @fields = Hash.new { _1[_2] = [] }
  end

  def start_span(name:)
    @spans << name
    yield self
  end

  def add_field(key, value)
    @fields[key] << value
  end
end
