# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FitGapGeneratorWorker do
  let(:portfolio) { create(:portfolio) }
  let(:vacancy) { create(:vacancy) }

  before { FitGap::GenerationLock.acquire(portfolio.id, vacancy.id) }

  it 'releases the generation lock when it succeeds' do
    allow(FitGap::Engine).to receive(:new).and_return(instance_double(FitGap::Engine, call: nil))

    described_class.new.perform(portfolio.id, vacancy.id)

    expect(FitGap::GenerationLock.held?(portfolio.id, vacancy.id)).to be(false)
  end

  it 'releases the generation lock when it fails, so a retry or a new request can run' do
    allow(FitGap::Engine).to receive(:new).and_raise(ActiveRecord::StatementInvalid, 'boom')

    expect { described_class.new.perform(portfolio.id, vacancy.id) }.to raise_error(ActiveRecord::StatementInvalid)
    expect(FitGap::GenerationLock.held?(portfolio.id, vacancy.id)).to be(false)
  end
end
