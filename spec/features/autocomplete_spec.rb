# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Autocomplete', type: :feature, js: true do
  context 'site-wide search form' do
    it 'is configured properly to allow non-prefix autocomplete' do
      visit '/'
      page.execute_script <<-EOF
        $("[data-autocomplete-enabled]:visible").val("by-laws").trigger("input");
        $("[data-autocomplete-enabled]:visible").typeahead("open");
      EOF

      within('.tt-menu') do
        expect(page).to have_css('.tt-suggestion', text: 'constitution and by-laws', visible: true)
      end
    end
  end
end
