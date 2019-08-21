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
    # binding.pry
    Arclight::Traject::NokogiriNamespacelessReader.new(fixture_file.to_s, indexer.settings)
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
      expect(result['ead_ssi'].first).to eq 'a0011-xml'
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
      it 'repository' do
        %w[repository_sim repository_ssm].each do |field|
          expect(first_component[field]).to include 'Stanford University Libraries. Special Collections and University Archives'
        end
      end

      it 'has_online_content' do
        expect(first_component['has_online_content_ssim']).to eq([true])
      end

      it 'digital_objects' do
        expect(first_component['digital_objects_ssm']).to eq(
          [
            JSON.generate(
              label: 'Photograph Album',
              href: 'http://purl.stanford.edu/kc844kt2526'
            )
          ]
        )
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

    it 'control access within a component' do
      component = result['components'].find { |c| c['id'] == ['aoa271aspace_81c806b82a14c3c79d395bbd383b886f'] }
      %w[access_subjects_ssm access_subjects_ssim].each do |field|
        expect(component).to include field
        expect(component[field]).to contain_exactly 'Minutes'
      end
    end

    it 'indexes geognames' do
      component = result['components'].find { |d| d['id'] == ['aoa271aspace_843e8f9f22bac69872d0802d6fffbb04'] }
      expect(component).to include 'geogname_sim'
      expect(component['geogname_sim']).to include('Popes Creek (Md.)')

      expect(component).to include 'geogname_ssm'
      expect(component['geogname_ssm']).to include('Popes Creek (Md.)')
    end

    context 'with nested controlaccess elements' do
      let(:fixture_path) do
        Arclight::Engine.root.join('spec', 'fixtures', 'ead', 'ncaids544-id-test.xml')
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
  end

  describe 'for EAD Documents without XML namespaces' do
    let(:fixture_without_namespaces) do
      doc = Nokogiri::XML.parse(fixture_file.to_s)
      doc.remove_namespaces!
      doc.to_xml
    end
    let(:nokogiri_reader) do
      Arclight::Traject::NokogiriNamespacelessReader.new(fixture_without_namespaces, indexer.settings)
    end

    it 'id' do
      expect(result['id'].first).to eq 'a0011-xml'
      expect(result['ead_ssi'].first).to eq 'a0011-xml'
    end

    it 'title' do
      %w[title_ssm title_teim].each do |field|
        expect(result[field]).to include 'Stanford University student life photograph album'
      end
      expect(result['normalized_title_ssm']).to include 'Stanford University student life photograph album, circa 1900-1906'
    end
  end
end
