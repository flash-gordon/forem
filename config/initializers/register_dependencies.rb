module PracticalDeveloper
  if Rails.env.production? || Rails.env.development?
    Container[:tracing] = Tracing.new(Honeycomb)
  end

  Container.freeze
end
