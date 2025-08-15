# Test for integrating Aegis summaries into history messages
require 'rspec'
require_relative '../mnemosyne'

describe 'Aegis summaries in history' do
  it 'limits summaries by token count' do
    max_tokens = 500
    summaries = Mnemosyne.fetch_aegis_summaries(before: '2025-09-10', max_tokens: max_tokens)
    expect(summaries.length).to be > 1
  end

  it 'filters summaries by date' do
    summaries = Mnemosyne.fetch_aegis_summaries(before: '2025-09-10', max_tokens: 100)
    expect(summaries).to include("Implemented restart mechanism for temperature parameter adjustments")
    expect(summaries).to include("Implemented restart mechanism for temperature adjustments in Oracle")
  end
end
