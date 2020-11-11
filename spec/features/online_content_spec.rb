# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Online Content', type: :feature do
  let(:doc_id) { 'aoa271aspace_843e8f9f22bac69872d0802d6fffbb04' }

  before { visit solr_document_path(id: doc_id) }

  describe 'Viewer' do
    context 'embedded content' do
      let(:doc_id) { 'a0011-xmlaspace_ref6_lx4' }

      it 'renders digital object viewer initialization markup', js: true do
        expect(page).to have_css(
          '.al-oembed-viewer[data-arclight-oembed-url="http://purl.stanford.edu/kc844kt2526"]',
          visible: false
        )
      end
    end

    context 'non-embeddable content' do
      let(:doc_id) { 'aoa271aspace_843e8f9f22bac69872d0802d6fffbb04' }

      it 'renders a list of links', js: true do
        expect(page).to have_link('Folder of digitized stuff')
        expect(page).to have_css('a', text: /^Letter from Christian B. Anfinsen/)
      end
    end

    context 'a collection w/o digital objects at the collection level' do
      let(:doc_id) { 'a0011-xml' }

      it 'renders a flat list of the child components with online content', js: true do
        click_link('Online content')

        within('#online-content') do
          expect(page).to have_css('article', count: 1)

          expect(page).to have_css('.document-title-heading', text: 'Photograph Album')
        end
      end

      it 'document container is not visible', js: true do
        click_link('Online content')

        within('#online-content') do
          expect(page).to have_css('article', count: 1)

          expect(page).not_to have_css('.al-document-container', text: 'Box 1')
        end
      end
    end

    context 'no content' do
      let(:doc_id) { 'aoa271aspace_a951375d104030369a993ff943f61a77' }

      it 'does not render online content tab' do
        expect(page).not_to have_css('.nav-link', text: 'Online content')
      end
    end

    context 'with multiple pages of online content' do
      let(:doc_id) { 'umich-bhl-851981aspace_9b5b0ff697f0a78a48bad43c55ad324e' }

      it 'has next/previous controls', js: true do
        click_link 'Online content'

        expect(page).to have_css '.page-entries', text: '1 - 10 of 12 entries'

        click_link 'Next »'

        expect(page).to have_css '.page-entries', text: '11 - 12 of 12 entries'

        click_link '« Previous'

        expect(page).to have_css '.page-entries', text: '1 - 10 of 12 entries'
      end

      it 'adds the count badge', js: true do
        expect(page).to have_css '.al-online-content-badge', text: '12', count: 1
        click_link 'Online content'
        click_link 'Next »'
        expect(page).to have_css '.al-online-content-badge', text: '12', count: 1
      end
    end
  end
end
