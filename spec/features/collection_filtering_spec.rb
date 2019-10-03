# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Collection filtering', type: :feature do
  context 'when in a search result filtered by collection' do
    it 'has the a select input with the "this collection" option selected' do
      visit search_catalog_path(f: { collection_sim: ['Alpha Omega Alpha Archives, 1894-1992'] })

      within 'form.search-query-form' do
        expect(page).to have_select('Search', selected: 'this collection')
      end
    end

    it 'clears the collection filter when "all collections" is selected' do
      visit search_catalog_path(q: 'File', f: { collection_sim: ['Alpha Omega Alpha Archives, 1894-1992'] })

      expect(page).to have_css('.constraint-value .filter-value', text: 'Alpha Omega Alpha Archives, 1894-1992')

      select 'all collections', from: 'Search'

      click_button 'Search'

      expect(page).to have_css('#documents .document', count: 10) # has results
      expect(page).not_to have_css('.constraint-value .filter-value', text: 'Alpha Omega Alpha Archives, 1894-1992')
    end
  end

  context 'when in a search result not filtered by collection' do
    it 'has the a select input with the "this collection" option disabled' do
      visit search_catalog_path(q: 'File')

      within 'form.search-query-form' do
        expect(page).to have_select('Search', selected: 'all collections')
        expect(page).to have_css('#within_collection option[disabled]', text: 'this collection')
      end
    end
  end

  context 'when on a record view' do
    it 'has the a select input with the "this collection" option selected' do
      visit solr_document_path('lc0100aspace_327a75c226d44aa1a769edb4d2f13c6e')

      within 'form.search-query-form' do
        expect(page).to have_select('Search', selected: 'this collection')
      end
    end

    it 'searches within the collection context by default' do
      visit solr_document_path('aoa271aspace_dba76dab6f750f31aa5fc73e5402e71d')

      fill_in 'q', with: 'File'
      click_button 'Search'

      expect(page).to have_css('.constraint-value .filter-value', text: 'Alpha Omega Alpha Archives, 1894-1992')
      expect(page).to have_css('#documents .document', count: 1) # has results
    end

    it 'allows the user to choose to search all collections' do
      visit solr_document_path('aoa271aspace_dba76dab6f750f31aa5fc73e5402e71d')

      select 'all collections', from: 'Search'
      fill_in 'q', with: 'File'
      click_button 'Search'

      expect(page).not_to have_css('.constraint-value .filter-value', text: 'Alpha Omega Alpha Archives, 1894-1992')
      expect(page).to have_css('#documents .document', count: 10) # has results
    end
  end
end
