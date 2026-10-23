# frozen_string_literal: true

module FitGap
  # At most one fit/gap generation per (portfolio, vacancy) at a time, across tabs, users and
  # processes. Taken when a job is enqueued and released by the worker when it finishes; the TTL
  # frees it if a worker dies first.
  module GenerationLock
    TTL = 5.minutes

    module_function

    def acquire(portfolio_id, vacancy_id)
      Sidekiq.redis { |r| r.call('SET', key(portfolio_id, vacancy_id), '1', 'NX', 'EX', TTL.to_i) } == 'OK'
    end

    def release(portfolio_id, vacancy_id)
      Sidekiq.redis { |r| r.call('DEL', key(portfolio_id, vacancy_id)) }
    end

    def held?(portfolio_id, vacancy_id)
      Sidekiq.redis { |r| r.call('EXISTS', key(portfolio_id, vacancy_id)) } == 1
    end

    def key(portfolio_id, vacancy_id)
      "fitgap:generating:#{portfolio_id}:#{vacancy_id}"
    end
  end
end
