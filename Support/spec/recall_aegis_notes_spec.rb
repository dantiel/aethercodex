# Test for integrating Aegis summaries into history messages
require 'rspec'
require_relative '../arcanum'

describe 'Aegis summaries in history' do
  it 'limits summaries by token count' do
    max_tokens = 50
    summaries = Arcanum.fetch_aegis_summaries(since: '2025-08-10', max_summary_tokens: max_tokens)
    expect(summaries.length).to eq(1)
  end

  it 'filters summaries by date' do
    summaries = Arcanum.fetch_aegis_summaries(since: '2025-08-10', max_summary_tokens: 100)
    expect(summaries).to include("Implemented restart mechanism for temperature parameter adjustments")
    expect(summaries).to include("Implemented restart mechanism for temperature adjustments in Oracle")
  end
end
