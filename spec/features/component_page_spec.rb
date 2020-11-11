# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Component Page', type: :feature do
  let(:doc_id) { 'aoa271aspace_843e8f9f22bac69872d0802d6fffbb04' }
  let(:download_config) do
    ActiveSupport::HashWithIndifferentAccess.new(
      default: {
        pdf: {
          href: 'http://example.com/sample.pdf',
          size: '1.23MB'
        },
        ead: {
          href: 'http://example.com/sample.xml',
          size: 123_456
        }
      }
    )
  end

  before do
    allow(Arclight::DocumentDownloads).to receive(:config).and_return(download_config)
    visit solr_document_path(id: doc_id)
  end

  describe 'tabbed display' do
    it 'clicking context toggles visibility', js: true do
      expect(page).to have_css '#context', visible: true
      expect(page).to have_css '#access', visible: false
      click_link 'Access'
      expect(page).to have_css '#context', visible: false
      expect(page).to have_css '#access', visible: true
    end
  end

  describe 'label/title' do
    it 'does not double escape entities in the heading' do
      expect(page).to have_css('h1', text: /"A brief account of the origin of/)
      expect(page).not_to have_css('h1', text: /^&quot;A brief account of the origin of/)
    end
  end

  describe 'Indexed Terms names section' do
    it 'includes names dt subheading text' do
      expect(page).to have_css('dt.blacklight-names_ssim', text: 'Names:')
    end

    it 'includes names dd link text' do
      expect(page).to have_css('dd a', text: "Robertson's Crab House")
    end
  end

  describe 'Indexed Terms places section' do
    it 'includes places dt subheading text' do
      expect(page).to have_css('dt.blacklight-places_ssim', text: 'Places:')
    end

    it 'includes places dd link text' do
      expect(page).to have_css('dd a', text: 'Popes Creek (Md.)')
    end
  end

  describe 'Indexed Terms subjects section' do
    let(:doc_id) { 'aoa271aspace_01daa89087641f7fc9dbd7a10d3f2da9' }

    it 'includes subjects dt subheading text' do
      expect(page).to have_css('dt.blacklight-access_subjects_ssim', text: 'Subjects:')
    end

    it 'includes subjects dd link text' do
      expect(page).to have_css('dd.blacklight-access_subjects_ssim a', text: 'Records')
    end
  end

  describe 'direct online content items' do
    it 'includes links to online content' do
      expect(page).to have_css('.al-digital-object.breadcrumb-item', text: 'Folder of digitized stuff')
    end
  end

  describe 'metadata' do
    let(:doc_id) { 'aoa271aspace_dc2aaf83625280ae2e193beb3f4aea78' }

    it 'uses our rules for displaying containers' do
      expect(page).to have_css('dd', text: 'Box 1, Folder 4-5')
    end

    it 'shows misc notes' do
      expect(page).to have_css('dt', text: 'Appraisal information')
      expect(page).to have_css('dd', text: /^Materials for this group were selected/)
      expect(page).to have_css('dt', text: 'Custodial history')
      expect(page).to have_css('dd', text: /^These papers were maintained by the staff/)
    end

    it 'multivalued notes are rendered as paragaphs' do
      within 'dd.blacklight-appraisal_ssm' do
        expect(page).to have_css('p', count: 2)
      end
    end
  end

  describe 'collection context', js: true do
    it 'has ancestor component with badge having children count' do
      within '#collection-context' do
        expect(page).to have_css(
          'li a',
          text: 'Series I: Administrative Records, 1902-1976'
        )
        expect(page).to have_css('.al-number-of-children-badge', text: '25')
        expect(page).to have_css('.al-online-content-icon')
        expect(page).to have_css('form.bookmark-toggle')
        expect(page).to have_css '.al-document-container', text: 'Box 1, Folder 1'
      end
    end

    context 'siblings and highlighted self' do
      it 'has all siblings' do
        within '#collection-context' do
          expect(page).to have_css(
            'li.al-hierarchy-highlight:nth-child(1)',
            text: /"A brief account of the origin/
          )
          expect(page).to have_css 'li:nth-child(2)', text: 'Statements of purpose, c.1902'
          expect(page).to have_css 'li:nth-child(3)',
                                   text: 'Constitution - notes on drafting of constitution, c.1902-1903'
          expect(page).to have_css 'li', count: 32
        end
      end
    end
    it 'supports clicks within collection context' do
      within '#collection-context' do
        click_link('Statements of purpose, c.1902')
      end
      expect(page).to have_css 'h1', text: 'Statements of purpose, c.1902'
      within '#collection-context' do
        expect(page).to have_css 'li.al-hierarchy-highlight', text: 'Statements of purpose, c.1902'
        expect(page).to have_css '.document-title-heading', text: /"A brief account of the origin/
        expect(page).to have_css '.al-document-container', text: 'Box 1, Folder 1'
        expect(page).to have_css(
          '.document-title-heading',
          text: 'Constitution - notes on drafting of constitution, c.1902-1903'
        )
        click_link 'Constitution - notes on drafting of constitution, c.1902-1903'
      end
      expect(page).to have_css 'h1', text: 'Constitution - notes on drafting of constitution, c.1902-1903'
      within '#collection-context' do
        expect(page).to have_css(
          'li.al-hierarchy-highlight',
          text: 'Constitution - notes on drafting of constitution, c.1902-1903'
        )
        first('.btn-secondary', text: 'Expand').click
        expect(page).to have_css '.document-title-heading', text: 'Statements of purpose, c.1902'
        expect(page).to have_css '.document-title-heading', text: 'Constitution and by-laws - drafts, 1902-1904'
      end
    end

    context 'duplicate titles' do
      let(:doc_id) { 'lc0100aspace_c5ef89d4ae68bb77e7c641f3edb3f1c8' }

      it 'does not highlight duplicate titles' do
        within '#collection-context .al-hierarchy-highlight' do
          expect(page).to have_css '.document-title-heading', text: 'Item AA201', count: 1
        end
      end
    end

    context 'when there are more than two previous sibling documents for the current document' do
      let(:doc_id) { 'm0198-xmlaspace_ref13_yl7' }

      it 'hides all but the first previous sibling document items' do
        within '#collection-context' do
          expect(page).to have_css '.document-title-heading', text: 'Pages 273-353'
          expect(page).to have_css '.document-title-heading', text: 'Pages 171-272'
          expect(page).to have_css '.document-title-heading', text: 'Pages 79-170'
          expect(page).not_to have_css '.document-title-heading', text: 'Pages 1-78'
        end
      end

      it 'offers a button for displaying the hidden sibling document items' do
        within '#collection-context' do
          expect(page).to have_css '.btn-secondary', text: 'Expand'
          expect(page).not_to have_css '.document-title-heading', text: 'Pages 1-78'
          expect(page).to have_css '.document-title-heading', text: 'Pages 79-170'
          expect(page).to have_css '.document-title-heading', text: 'Pages 171-272'
          expect(page).to have_css '.document-title-heading', text: 'Pages 273-353'

          first('.btn-secondary', text: 'Expand').click

          expect(page).to have_css '.btn-secondary', text: 'Collapse'
          expect(page).to have_css '.document-title-heading', text: 'Pages 1-78'

          first('.btn-secondary', text: 'Collapse').click

          expect(page).to have_css '.btn-secondary', text: 'Expand'
          expect(page).not_to have_css '.document-title-heading', text: 'Pages 1-78'
        end
      end
    end

    context 'when on a deeply nested component' do
      let(:doc_id) { 'aoa271aspace_6ea193f778e553ca9ea0d00a3e5a1891' }

      it 'enables expanding nodes outside of own ancestor tree' do
        within '#collection-context' do
          find('#aoa271aspace_01daa89087641f7fc9dbd7a10d3f2da9 .al-toggle-view-children').click
          expect(page).to have_css '.document-title-heading', text: 'Miscellaneous 1999'
        end
      end
    end

    context 'when on a component with an eadid with . normalized to -' do
      let(:doc_id) { 'pc0170-xmlaspace_ref1_z0j' }

      it 'expands child nodes when clicked' do
        within '#collection-context' do
          find('#pc0170-xmlaspace_ref5_edi .al-toggle-view-children').click
          expect(page).to have_css '.document-title-heading', text: 'Restricted images, 1979-2000'
        end
      end
    end
  end

  describe 'access tab', js: true do
    it 'has visitation notes' do
      click_link 'Access'
      expect(page).to have_css 'dt', text: 'LOCATION OF THIS COLLECTION:'
      expect(page).to have_css 'dd', text: 'Building 38, Room 1E-21'
    end

    it 'has a restrictions and access' do
      click_link 'Access'
      expect(page).to have_css 'dt', text: 'PARENT RESTRICTIONS:'
      expect(page).to have_css 'dd', text: /^RESTRICTED: Access to these folders requires prior written approval./
      expect(page).to have_css 'dt', text: 'TERMS OF ACCESS:'
      expect(page).to have_css 'dd', text: /^Copyright was transferred to the public domain./
    end

    it 'has a contact' do
      click_link 'Access'
      expect(page).to have_css 'dt', text: 'CONTACT:'
      expect(page).to have_css 'dd', text: 'hmdref@nlm.nih.gov'
    end
  end

  describe 'breadcrumb' do
    it 'links home, collection, and parents' do
      within '.al-show-breadcrumb' do
        expect(page).to have_css 'a', text: 'Home'
        expect(page).to have_css 'a', text: 'National Library of Medicine. History of Medicine Division'
        expect(page).to have_css 'a', text: 'Alpha Omega Alpha Archives, 1894-1992'
        expect(page).to have_css 'a', text: 'Series I: Administrative Records, 1902-1976, bulk 1975-1976'
        expect(page).to have_css 'a', count: 4
      end
    end
  end

  context 'content with file downloads', js: true do
    let(:doc_id) { 'a0011-xmlaspace_ref6_lx4' }

    it 'renders links to the files for download' do
      within '.al-show-actions-box-downloads-container' do
        expect(page).to have_css('a', text: 'Download finding aid (1.23MB)')
        expect(page).to have_css('a', text: 'Download EAD (123456)')
      end
    end
  end
end
