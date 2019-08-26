# frozen_string_literal: true

require 'spec_helper'

describe 'EAD 2 traject indexing', type: :feature do
  subject(:result) do
    indexer.map_record(record)
  end

  let(:indexer) do
    Traject::Indexer::NokogiriIndexer.new.tap do |i|
      i.load_config_file(Arclight::Engine.root.join('lib/arclight/traject/ead2_config.rb'))
    end
  end
  let(:fixture_path) do
    Arclight::Engine.root.join('spec', 'fixtures', 'ead', 'sul-spec', 'a0011.xml')
  end
  let(:fixture_file) do
    File.read(fixture_path)
  end
  let(:nokogiri_reader) do
    Traject::NokogiriReader.new(fixture_file.to_s, {})
  end
  let(:records) do
    nokogiri_reader.to_a
  end
  let(:record) do
    records.first
  end

  before do
    ENV['REPOSITORY_ID'] = nil
  end

  after do # ensure we reset these otherwise other tests will fail
    ENV['REPOSITORY_ID'] = nil
  end

  describe 'solr fields' do
    before do
      ENV['REPOSITORY_ID'] = 'sul-spec'
    end

    it 'id' do
      expect(result['id'].first).to eq 'a0011-xml'
      expect(result['ead_ssi'].first).to eq 'a0011.xml'
    end
    it 'title' do
      %w[title_ssm title_teim].each do |field|
        expect(result[field]).to include 'Stanford University student life photograph album'
      end
      expect(result['normalized_title_ssm']).to include 'Stanford University student life photograph album, circa 1900-1906'
    end
    it 'level' do
      expect(result['level_ssm']).to eq ['collection']
      expect(result['level_sim']).to eq ['Collection']
    end
    it 'dates' do
      expect(result['normalized_date_ssm']).to include 'circa 1900-1906'
      expect(result['unitdate_bulk_ssim']).to be_nil
      expect(result['unitdate_inclusive_ssim']).to include 'circa 1900-1906'
      expect(result['unitdate_other_ssim']).to be_nil
    end

    it 'creates date_range_sim' do
      date_range = result['date_range_sim']
      expect(date_range).to be_an Array
      expect(date_range.length).to eq 7
      expect(date_range.first).to eq 1900
      expect(date_range.last).to eq 1906
    end

    it 'repository' do
      %w[repository_sim repository_ssm].each do |field|
        expect(result[field]).to include 'Stanford University Libraries. Special Collections and University Archives'
      end
    end

    it 'geogname' do
      %w[geogname_sim geogname_ssm].each do |field|
        expect(result[field]).to include 'Yosemite National Park (Calif.)'
      end
    end

    it 'unitid' do
      expect(result['unitid_ssm']).to eq ['A0011']
    end

    it 'creator' do
      %w[creator_ssm creator_ssim creator_corpname_ssm creator_corpname_ssim creators_ssim creator_sort].each do |field|
        expect(result[field]).to eq ['Stanford University']
      end
    end

    it 'places' do
      expect(result['places_ssim']).to eq ['Yosemite National Park (Calif.)']
    end

    it 'has_online_content' do
      expect(result['has_online_content_ssim']).to eq [true]
    end

    it 'collection has normalized_title' do
      %w[collection_ssm collection_sim].each do |field|
        expect(result[field]).to include 'Stanford University student life photograph album, circa 1900-1906'
      end
    end

    describe 'components' do
      let(:first_component) { result['components'].first }

      it 'ref' do
        %w[ref_ssm ref_ssi].each do |field|
          expect(first_component[field]).to include 'aspace_ref6_lx4'
        end
      end
      it 'id' do
        expect(first_component).to include 'id' => ['a0011-xmlaspace_ref6_lx4']
      end
      it 'ead_ssi should be parents' do
        expect(first_component['ead_ssi']).to eq result['ead_ssi']
      end
      it 'repository' do
        %w[repository_sim repository_ssm].each do |field|
          expect(first_component[field]).to include 'Stanford University Libraries. Special Collections and University Archives'
        end
      end

      it 'has_online_content' do
        expect(first_component['has_online_content_ssim']).to eq([true])
      end

      it 'digital_objects' do
        # rubocop:disable Style/StringLiterals
        expect(first_component['digital_objects_ssm']).to eq(["{\"label\":\"Photograph Album\",\"href\":\"http://purl.stanford.edu/kc844kt2526\"}"])
        # rubocop:enable Style/StringLiterals
      end

      it 'geogname' do
        %w[geogname_sim geogname_ssm].each do |field|
          expect(result['components'].first[field]).to be_nil
        end
      end

      it 'collection has normalized title' do
        %w[collection_sim collection_ssm].each do |field|
          expect(first_component[field]).to include 'Stanford University student life photograph album, circa 1900-1906'
        end
      end
      it 'creator' do
        %w[collection_creator_ssm].each do |field|
          expect(first_component[field]).to eq ['Stanford University']
        end
      end

      it 'containers' do
        component = result['components'].find { |c| c['ref_ssi'] == ['aspace_ref6_lx4'] }
        expect(component['containers_ssim']).to eq ['box 1']
      end

      describe 'levels' do
        let(:fixture_path) do
          Arclight::Engine.root.join('spec', 'fixtures', 'ead', 'nlm', 'alphaomegaalpha.xml')
        end
        let(:level_component) { result['components'].find { |c| c['ref_ssi'] == ['aspace_a951375d104030369a993ff943f61a77'] } }
        let(:other_level_component) { result['components'].find { |c| c['ref_ssi'] == ['aspace_e6db65d47e891d61d69c2798c68a8f02'] } }

        it 'is the level Capitalized' do
          expect(level_component['level_ssm']).to eq(['Series'])
        end

        it 'is the otherlevel attribute when the level attribute is "otherlevel"' do
          expect(other_level_component['level_ssm']).to eq(['Binder'])
        end
      end
    end
  end

  describe 'large component list' do
    let(:fixture_path) do
      Arclight::Engine.root.join('spec', 'fixtures', 'ead', 'sample', 'large-components-list.xml')
    end

    it 'selects the components' do
      expect(result['components'].length).to eq 404
    end

    context 'when nested component' do
      let(:nested_component) { result['components'].find { |c| c['id'] == ['lc0100aspace_32ad9025a3a286358baeae91b5d7696e'] } }

      it 'correctly determines component level' do
        expect(nested_component['component_level_isim']).to eq [2]
      end

      it 'parent' do
        expect(nested_component['parent_ssm']).to eq %w[lc0100 aspace_327a75c226d44aa1a769edb4d2f13c6e]
        expect(nested_component['parent_ssi']).to eq ['aspace_327a75c226d44aa1a769edb4d2f13c6e']
      end

      it 'parent_unittitles' do
        expect(nested_component['parent_unittitles_ssm']).to eq ['Large collection sample, 1843-1872', 'File 1']
      end
    end
  end

  describe 'containers in a component' do
    let(:fixture_path) do
      Arclight::Engine.root.join('spec', 'fixtures', 'ead', 'nlm', 'alphaomegaalpha.xml')
    end

    it 'only indexes containers within a given component' do
      component = result['components'].find { |c| c['id'] == ['aoa271aspace_843e8f9f22bac69872d0802d6fffbb04'] }
      expect(component['containers_ssim']).to eq ['box 1', 'folder 1']
    end
  end

  describe 'for control access elements' do
    let(:fixture_path) do
      Arclight::Engine.root.join('spec', 'fixtures', 'ead', 'nlm', 'alphaomegaalpha.xml')
    end

    it 'indexes the values as controlled vocabulary terms' do
      %w[access_subjects_ssm access_subjects_ssim].each do |field|
        expect(result).to include field
        expect(result[field]).to contain_exactly(
          'Fraternizing',
          'Medicine',
          'Photographs',
          'Societies'
        )
      end
    end

    it 'indexes collection-level names' do
      expect(result['names_coll_ssim']).to contain_exactly(
        'Alpha Omega Alpha',
        'Root, William Webster, 1867-1932',
        'Bierring, Walter L. (Walter Lawrence), 1868-1961'
      )
    end

    it 'indexes controlaccess subjects within a component' do
      component = result['components'].find { |c| c['id'] == ['aoa271aspace_81c806b82a14c3c79d395bbd383b886f'] }
      %w[access_subjects_ssm access_subjects_ssim].each do |field|
        expect(component).to include field
        expect(component[field]).to contain_exactly 'Minutes'
      end
    end

    it 'indexes controlaccess names within a component' do
      component = result['components'].find { |c| c['id'] == ['aoa271aspace_843e8f9f22bac69872d0802d6fffbb04'] }
      expect(component).to include 'names_ssim'
      expect(component['names_ssim']).to include('Robertson\'s Crab House')
    end

    it 'indexes geognames' do
      component = result['components'].find { |d| d['id'] == ['aoa271aspace_843e8f9f22bac69872d0802d6fffbb04'] }
      expect(component).to include 'geogname_sim'
      expect(component['geogname_sim']).to include('Popes Creek (Md.)')

      expect(component).to include 'geogname_ssm'
      expect(component['geogname_ssm']).to include('Popes Creek (Md.)')
    end

    it 'creates date_range_sim' do
      component = result['components'].find { |d| d['id'] == ['aoa271aspace_563a320bb37d24a9e1e6f7bf95b52671'] }
      date_range = component['date_range_sim']
      expect(date_range).to be_an Array
      expect(date_range.length).to eq 75
      expect(date_range.first).to eq 1902
      expect(date_range.last).to eq 1976
    end

    context 'with nested controlaccess elements' do
      let(:fixture_path) do
        Arclight::Engine.root.join('spec', 'fixtures', 'ead', 'nlm', 'ncaids544-id-test.xml')
      end

      it 'indexes the values as controlled vocabulary terms' do
        %w[access_subjects_ssm access_subjects_ssim].each do |field|
          expect(result).to include field
          expect(result[field]).to contain_exactly(
            'Acquired Immunodeficiency Syndrome',
            'African Americans',
            'Homosexuality',
            'Human Immunodeficiency Virus',
            'Public Health'
          )
        end
      end
    end

    describe 'for documents with <acqinfo> elements' do
      let(:fixture_path) do
        Arclight::Engine.root.join('spec', 'fixtures', 'ead', 'nlm', 'alphaomegaalpha.xml')
      end

      it 'indexes the values as stored facetable strings and multiple displayable strings' do
        expect(result).to include 'components'
        expect(result['components']).not_to be_empty
        first_component = result['components'].first

        expect(first_component).to include 'acqinfo_ssim'
        expect(first_component['acqinfo_ssim']).to contain_exactly(
          'Donated by Alpha Omega Alpha.'
        )

        expect(first_component).to include 'acqinfo_ssm'
        expect(first_component['acqinfo_ssm']).to contain_exactly(
          'Donated by Alpha Omega Alpha.'
        )
      end

      context 'when documents have <acqinfo> elements within <descgrp> elements' do
        let(:fixture_path) do
          Arclight::Engine.root.join('spec', 'fixtures', 'ead', 'nlm', 'ncaids544-id-test.xml')
        end

        it 'indexes the values as stored facetable strings and multiple displayable strings' do
          expect(result).to include 'components'
          expect(result['components']).not_to be_empty
          first_component = result['components'].first

          expect(first_component).to include 'acqinfo_ssim'
          expect(first_component['acqinfo_ssim']).to contain_exactly(
            "Gift, John L. Parascandola, PHS Historian's Office, 3/1/1994, Acc. #812. Gift, Donald Goldman, Acc. #2005-21."
          )

          expect(first_component).to include 'acqinfo_ssm'
          expect(first_component['acqinfo_ssm']).to contain_exactly(
            "Gift, John L. Parascandola, PHS Historian's Office, 3/1/1994, Acc. #812. Gift, Donald Goldman, Acc. #2005-21."
          )
        end
      end
    end
  end
end
