# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Collection context', type: :feature, js: true do
  let(:doc_id) { 'aoa271aspace_6ea193f778e553ca9ea0d00a3e5a1891' }

  before do
    visit solr_document_path(id: doc_id)
  end

  describe 'highly nested item' do
    it 'highlights the correct context item' do
      expect(page).to have_css '.al-hierarchy-highlight', text: 'Initial Phase'
    end

    it 'siblings are not expanded' do
      expect(page).to have_css '.al-toggle-view-children.collapsed[href="#aoa271aspace_b70574c7229e6f237f780579cc04595d-collapsible-hierarchy"]'
    end

    it 'direct ancestors are expanded' do
      expect(page).to have_css '#aoa271aspace_f934f1add34289f28bd0feb478e68275-collapsible-hierarchy.show', visible: true
      expect(page).to have_css '#aoa271aspace_238a0567431f36f49acea49ef576d408-collapsible-hierarchy.show', visible: true
      expect(page).to have_css '#aoa271aspace_563a320bb37d24a9e1e6f7bf95b52671-collapsible-hierarchy.show', visible: true
    end

    it 'siblings above are hidden' do
      expect(page).to have_css '#aoa271aspace_843e8f9f22bac69872d0802d6fffbb04', visible: false
    end
  end
end
