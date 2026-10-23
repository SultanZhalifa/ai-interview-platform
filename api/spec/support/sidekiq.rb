# frozen_string_literal: true

RSpec.configure do |config|
  # Jobs are pushed to an in-memory array instead of Redis.
  config.before do
    Sidekiq::Testing.fake!
    Sidekiq::Worker.clear_all
  end
end
