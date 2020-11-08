Pry::Commands.block_command "show-handlers" do
  output.puts Dry::Effects::Frame.stack.inspect
end
