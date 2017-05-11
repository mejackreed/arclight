# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Arclight::DigitalObject do
  subject(:instance) do
    described_class.new(label: 'An object label', href: 'https://example.com/an-object-href')
  end

  describe '#to_json' do
    it 'returns a json serialization of the object' do
      json = JSON.parse(instance.to_json)
      expect(json).to be_a Hash
      expect(json['label']).to eq 'An object label'
    end
  end

  describe "#{described_class}.from_json" do
    it 'returns an instance of the class given the parsed json' do
      deserialized = described_class.from_json(instance.to_json)
      expect(deserialized).to be_a described_class
      expect(deserialized.label).to eq 'An object label'
    end
  end
end