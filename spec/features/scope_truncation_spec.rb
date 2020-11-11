# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Scope truncation', type: :feature, js: true do
  context 'in search results' do
    it 'is truncated' do
      visit search_catalog_path q: 'series iii', search_field: 'all_fields'
      truncation_works 'be a nyan cat'
    end
  end
  context 'in hierarchy' do
    it 'is truncated' do
      visit solr_document_path 'aoa271'
      click_link 'Contents'
      truncation_works 'be a nyan cat'
    end
  end
  context 'respository path' do
    it 'is truncated' do
      visit arclight_engine.repository_path 'sul-spec'
      truncation_works 'include Yosemite'
    end
  end
end

# rubocop:disable Metrics/AbcSize
def truncation_works(text)
  expect(page).to have_css 'a.responsiveTruncatorToggle', text: 'view more ▶'
  expect(page).to have_css '.al-document-abstract-or-scope', text: /#{text}/, visible: false
  first(:link, 'view more ▶').click
  expect(page).to have_css 'a.responsiveTruncatorToggle', text: 'view less ▼'
  expect(page).to have_css '.al-document-abstract-or-scope', text: /#{text}/, visible: true
end
# rubocop:enable Metrics/AbcSize
