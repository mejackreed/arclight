# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Collection Page', type: :feature do
  let(:doc_id) { 'aoa271' }

  before do
    visit solr_document_path(id: doc_id)
  end

  describe 'arclight document header' do
    it 'includes a div with the repository and collection ID' do
      within('.al-document-title-bar') do
        expect(page).to have_content 'National Library of Medicine. History of Medicine Division'
        expect(page).to have_content 'Collection ID: MS C 271'
      end
    end
  end

  describe 'online content indicator' do
    context 'when there is online content available' do
      it 'is rendered' do
        expect(page).to have_css('.badge-success', text: 'online content')
      end
    end

    context 'when there is no online content avilable' do
      let(:doc_id) { 'm0198-xml' }

      it 'is not rendered' do
        expect(page).not_to have_css('.badge-success', text: 'online content')
      end
    end
  end

  describe 'custom metadata sections' do
    it 'summary has configured metadata' do
      within '#summary' do
        expect(page).to have_css('dt', text: 'Creator')
        expect(page).to have_css('dd', text: 'Alpha Omega Alpha')
        expect(page).to have_css('dt', text: 'Abstract')
        expect(page).to have_css('dd', text: /was founded in 1902/)
        expect(page).to have_css('dt', text: 'Extent')
        expect(page).to have_css('dd', text: /15.0 linear feet/)
        expect(page).to have_css('dt', text: 'Preferred citation')
        expect(page).to have_css('dd', text: /Medicine, Bethesda, MD/)
      end
    end
    it 'access and use has configured metadata' do
      within '#access-and-use' do
        expect(page).to have_css('dt', text: 'Conditions Governing Access')
        expect(page).to have_css('dd', text: 'No restrictions on access.')
        expect(page).to have_css('dt', text: 'Terms Of Use')
        expect(page).to have_css('dd', text: /Copyright was transferred/)
      end
    end

    it 'notes are rendered as paragaphs' do
      within 'dd.blacklight-bioghist_ssm' do
        expect(page).to have_css('p', count: 2)
        expect(page).to have_css('p', text: /^Alpha Omega Alpha Honor Medical Society was founded/)
        expect(page).to have_css('p', text: /^Root and his fellow medical students/)
      end
    end

    it 'background has configured metadata' do
      within '#background' do
        expect(page).to have_css('dt', text: 'Scope and Content')
        expect(page).to have_css('dd', text: /^Correspondence, documents, records, photos/)

        expect(page).to have_css('dt', text: 'Biographical / Historical')
        expect(page).to have_css('dd', text: /^Alpha Omega Alpha Honor Medical Society was founded/)

        expect(page).to have_css('dt', text: 'Acquisition information')
        expect(page).to have_css('dd', text: 'Donated by Alpha Omega Alpha.')

        expect(page).to have_css('dt', text: 'Appraisal information')
        expect(page).to have_css('dd', text: /^Corpus callosum something incredible/)

        expect(page).to have_css('dt', text: 'Custodial history')
        expect(page).to have_css('dd', text: 'Maintained by Alpha Omega Alpha and the family of William Root.')

        expect(page).to have_css('dt', text: 'Processing information')
        expect(page).to have_css('dd', text: /^Processed in 2001\. Descended from astronomers\./)
      end
    end

    it 'related has configured metadata' do
      within '#related' do
        expect(page).to have_css('dt', text: 'Related material')
        expect(page).to have_css('dd', text: /^An unprocessed collection includes/)

        expect(page).to have_css('dt', text: 'Separated material')
        expect(page).to have_css('dd', text: /^Birth, Apollonius of Perga brain/)

        expect(page).to have_css('dt', text: 'Other finding aids')
        expect(page).to have_css('dd', text: /^Li Europan lingues es membres del/)

        expect(page).to have_css('dt', text: 'Alternative form available')
        expect(page).to have_css('dd', text: /^Rig Veda a mote of dust suspended/)

        expect(page).to have_css('dt', text: 'Location of originals')
        expect(page).to have_css('dd', text: /^Something incredible is waiting/)
      end
    end

    it 'indexed terms has configured metadata' do
      within '#indexed-terms' do
        expect(page).to have_css('dt', text: 'Subjects')
        expect(page).to have_css('dt', text: 'Names')
        expect(page).to have_css('dt', text: 'Places')
        expect(page).to have_css('dd', text: 'Societies')
        expect(page).to have_css('dd', text: 'Photographs')
        expect(page).to have_css('dd', text: 'Medicine')
        expect(page).to have_css('dd', text: 'Alpha Omega Alpha')
        expect(page).to have_css('dd', text: 'Root, William Webster, 1867-1932')
        expect(page).to have_css('dd', text: 'Bierring, Walter L. (Walter Lawrence), 1868-1961')
        expect(page).to have_css('dd', text: 'Mindanao Island (Philippines)')
        expect(page).not_to have_css('dd', text: 'Higgins, L. Raymond')
      end
    end

    it 'indexed name terms link to the appropriate name facet' do
      name = 'Root, William Webster, 1867-1932'
      within '#indexed-terms' do
        click_link name
      end

      within '.blacklight-names_ssim.facet-limit-active' do
        expect(page).to have_css('.facet-label .selected', text: name)
      end
    end

    context 'sections that do not have metadata' do
      let(:doc_id) { 'm0198-xml' }

      it 'are not displayed' do
        expect(page).not_to have_css('.al-show-sub-heading', text: 'Related')
      end
    end
  end
  describe 'navigation bar' do
    it 'has configured links' do
      within '.al-sidebar-navigation-overview' do
        expect(page).to have_css 'a[href="#summary"]', text: 'Summary'
        expect(page).to have_css 'a[href="#access-and-use"]', text: 'Access and Use'
        expect(page).to have_css 'a[href="#background"]', text: 'Background'
        expect(page).to have_css 'a[href="#related"]', text: 'Related'
        expect(page).to have_css 'a[href="#indexed-terms"]', text: 'Indexed Terms'
      end
    end

    context 'for sections that do not have metadata' do
      let(:doc_id) { 'm0198-xml' }

      it 'does not include links to those sections' do
        within '.al-sidebar-navigation-overview' do
          expect(page).not_to have_css 'a[href="#related"]', text: 'Related'
        end
      end
    end

    describe 'context_sidebar' do
      context 'that has a visitation note' do
        let(:doc_id) { 'm0198-xml' }

        it 'has an in person card' do
          within '#accordion' do
            expect(page).to have_css '.card-header h3', text: 'In person'
            expect(page).to have_css '.card-body dt', text: 'Before you visit:'
            expect(page).to have_css '.card-body dd', text: /materials are stored offsite and must be paged/
            expect(page).to have_css '.card-body dt', text: 'Location of this collection:'
            expect(page).to have_css '.card-body dd a', text: /Special Collections and University Archives/
            expect(page).to have_css '.card-body dd .al-repository-contact-building', text: 'Green Library'
          end
        end
      end

      it 'has a terms and conditions card' do
        within '#accordion' do
          expect(page).to have_css '.card-header h3', text: 'Terms & Conditions'
          expect(page).to have_css '.card-body dt', text: 'Restrictions:'
          expect(page).to have_css '.card-body dd', text: 'No restrictions on access.'
          expect(page).to have_css '.card-body dt', text: 'Terms of Access:'
          expect(page).to have_css '.card-body dd', text: /^Copyright was transferred/
        end
      end

      it 'has a how to cite card' do
        within '#accordion' do
          expect(page).to have_css '.card-header h3', text: 'How to cite this collection'
          expect(page).to have_css '.card-body dt', text: 'Preferred citation'
          expect(page).to have_css '.card-body dd', text: /Omega Alpha Archives\. 1894-1992/
        end
      end
    end
  end

  describe 'search within' do
    it 'has only items from this collection' do
      within('.al-sticky-sidebar') do
        click_button 'Search'
      end
      within '#facet-collection_sim' do
        expect(page).to have_css 'li', count: 1
      end
    end

    it 'does not include the collection record' do
      within('.al-sticky-sidebar') do
        click_button 'Search'
      end

      expect(page).not_to have_css('h3.index_title', text: /Alpha Omega Alpha Archives/)
      expect(page).to have_css('.page-entries', text: '1 - 10 of 37')
    end
  end

  describe 'tabbed display' do
    context 'collection has online content', js: true do
      it 'clicking contents toggles visibility' do
        click_link 'Contents'
        expect(page).to have_css '#contents', visible: true
        expect(page).to have_css '#overview', visible: false
        click_link 'Overview'
        expect(page).to have_css '#overview', visible: true
        expect(page).to have_css '#contents', visible: false
      end
      it 'clicking online contents toggles visibility' do
        expect(page).to have_css '#overview', visible: true
        expect(page).to have_css '#online-content', visible: false
        click_link 'Online content'
        expect(page).to have_css '#overview', visible: false
        expect(page).to have_css '#online-content', visible: true
      end
    end

    context 'collection has no online content' do
      let(:doc_id) { 'm0198-xml' }

      it 'displays a disabled tab' do
        expect(page).to have_css 'a.nav-link.disabled', text: 'No online content'
      end
    end
  end

  describe 'overview and contents' do
    it 'contents are not visible by default' do
      expect(page).to have_css '#contents', visible: false
    end
    it 'overview is visible' do
      expect(page).to have_css '#overview', visible: true
    end
    describe 'interactions', js: true do
      before { click_link 'Contents' }
      it 'contents contain linked level 1 components' do
        within '#contents' do
          click_link 'Series I: Administrative Records, 1902-1976'
        end
        expect(page).to have_css '.show-document', text: /Series I: Administrative Records/
      end
      it 'component metadata' do
        within '#contents' do
          within '.document-position-0 ' do
            expect(page).to have_css(
              '.al-document-abstract-or-scope',
              text: /^SCOPE AND CONTENTS Administrative records include/i
            )
          end
        end
      end
      it 'sub components are viewable and expandable' do
        within '#contents' do
          within '.document-position-0' do
            click_link 'View'
            within '.blacklight-otherlevel.document-position-3' do
              expect(page).to have_css '.document-title-containers', text: /Box 1, Folder 4\-5/
            end
            expect(page).to have_css 'a', text: 'Reports'
            within '.blacklight-subseries.document-position-21' do
              click_link 'View'
              expect(page).to have_css 'a', text: 'Expansion Plan'
              within '.blacklight-subseries.document-position-0' do
                click_link 'View'
                expect(page).to have_css 'a', text: 'Initial Phase'
                expect(page).to have_css 'a', text: 'Phase II: Expansion'
              end
            end
          end
        end
      end
      it 'includes the number of direct children of the component and View link' do
        within '.document-position-0' do
          expect(page).to have_css(
            '.al-hierarchy-children-status .al-number-of-children-badge',
            text: /25 children\s+View/
          )
        end
      end
      it 'has bookmark controls' do
        expect(page).to have_css 'form.bookmark-toggle', count: 7
      end

      it 'clicking contents does not change the session results view context' do
        visit search_catalog_path q: '', search_field: 'all_fields'

        expect(page).to have_css('#documents.documents-list')
        expect(page).not_to have_css('#documents.documents-hierarchy')
      end
    end
  end
  describe 'breadcrumb' do
    it 'links home, collection, displays title' do
      within '.al-show-breadcrumb' do
        expect(page).to have_css 'a', text: 'Home'
        expect(page).to have_css 'a', text: 'Collections'
        expect(page).to have_content 'Alpha Omega Alpha Archives, 1894-1992'
      end
    end
  end
end
