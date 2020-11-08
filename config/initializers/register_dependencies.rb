module PracticalDeveloper
  # if Rails.env.production?
  Container[:tracing] = Tracing.new(Honeycomb)
  # end

  Container.freeze
end
