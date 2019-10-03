# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'catalog/_within_collection_dropdown.html.erb', type: :view do
  before do
    allow(view).to receive(:within_collection_context?).and_return(within_collection_context?)
    render
  end

  context 'when in a collection context' do
    let(:within_collection_context?) { true }

    it 'renders a name attribute on the select (so it will be sent through the form)' do
      expect(rendered).to have_css('select[name="within_collection"]')
    end

    it 'has the "this collection" option selected' do
      expect(rendered).to have_css('select option[selected]', text: 'this collection')
    end
  end

  context 'when not in a collection context' do
    let(:within_collection_context?) { false }

    it 'does not render a name attribute on the select (because it does not need to be sent through the form)' do
      expect(rendered).not_to have_css('select[name]')
    end

    it 'has the "all collections" option selected' do
      expect(rendered).to have_css('select option[selected]', text: 'all collections')
    end

    it 'has the "this collection" option disabled' do
      expect(rendered).to have_css('select option[disabled]', text: 'this collection')
    end
  end
end
