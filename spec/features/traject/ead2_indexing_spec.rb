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
      expect(result['unitdate_inclusive_ssm']).to include 'circa 1900-1906'
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

      describe 'levels' do
        let(:fixture_path) do
          Arclight::Engine.root.join('spec', 'fixtures', 'ead', 'nlm', 'alphaomegaalpha.xml')
        end
        let(:level_component) { result['components'].find { |c| c['ref_ssi'] == ['aspace_a951375d104030369a993ff943f61a77'] } }
        let(:other_level_component) { result['components'].find { |c| c['ref_ssi'] == ['aspace_e6db65d47e891d61d69c2798c68a8f02'] } }

        it 'is the level Capitalized' do
          expect(level_component['level_ssm']).to eq(['Series'])
          expect(level_component['level_sim']).to eq(['Series'])
        end

        it 'is the otherlevel attribute when the level attribute is "otherlevel"' do
          expect(other_level_component['level_ssm']).to eq(['Binder'])
          expect(other_level_component['level_sim']).to eq(['Binder'])
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

  describe 'searchable notes' do
    let(:fixture_path) do
      Arclight::Engine.root.join('spec', 'fixtures', 'ead', 'nlm', 'alphaomegaalpha.xml')
    end

    it '#bioghist' do
      expect(result['bioghist_ssm'].first).to match(/^Alpha Omega Alpha Honor Medical Society was founded/)
      expect(result['bioghist_teim'].second).to match(/Hippocratic oath/)
      expect(result['bioghist_heading_ssm'].first).to match(/^Historical Note/)
    end

    it '#relatedmaterial' do
      expect(result['relatedmaterial_ssm'].first).to match(/^An unprocessed collection includes/)
    end

    it 'abstract' do
      expect(result['abstract_ssm'].first).to match(/^Alpha Omega Alpha Honor Medical Society/)
    end

    it '#separatedmaterial' do
      expect(result['separatedmaterial_ssm'].first).to match(/^Birth, Apollonius of Perga brain/)
    end

    it '#otherfindaid' do
      expect(result['otherfindaid_ssm'].first).to match(/^Li Europan lingues es membres del/)
    end

    it '#altformavail' do
      expect(result['altformavail_ssm'].first).to match(/^Rig Veda a mote of dust suspended/)
    end

    it '#originalsloc' do
      expect(result['originalsloc_ssm'].first).to match(/^Something incredible is waiting/)
    end

    it '#arrangement' do
      expect(result['arrangement_ssm'].first).to eq 'Arranged into seven series.'
    end

    it '#acqinfo' do
      expect(result['acqinfo_ssm'].first).to eq 'Donated by Alpha Omega Alpha.'
    end

    it '#appraisal' do
      expect(result['appraisal_ssm'].first).to match(/^Corpus callosum something incredible/)
    end

    it '#custodhist' do
      expect(result['custodhist_ssm'].first).to eq 'Maintained by Alpha Omega Alpha and the family of William Root.'
    end

    it '#processinfo' do
      expect(result['processinfo_ssm'].first).to match(/^Processed in 2001\. Descended from astronomers\./)
    end
  end

  describe 'alphaomegaalpha list' do
    let(:record) do
      Traject::NokogiriReader.new(
        File.read(
          Arclight::Engine.root.join('spec', 'fixtures', 'ead', 'nlm', 'alphaomegaalpha.xml')
        ).to_s,
        {}
      ).to_a.first
    end

    it 'extent at the collection level' do
      %w[extent_ssm extent_teim].each do |field|
        expect(result[field]).to contain_exactly(
          "15.0 linear feet (36 boxes + oversize\n          folder)"
        )
      end
    end

    it 'extent at the component level' do
      component = result['components'].find { |c| c['ref_ssi'] == ['aspace_a951375d104030369a993ff943f61a77'] }
      %w[extent_ssm extent_teim].each do |field|
        expect(component[field]).to contain_exactly(
          "1.5 Linear\n              Feet"
        )
      end
    end

    it 'selects the components' do
      expect(result['components'].length).to eq 37
    end

    context 'when nested component' do
      let(:component_with_access_restrict) { result['components'].find { |c| c['ref_ssi'] == ['aspace_dba76dab6f750f31aa5fc73e5402e71d'] } }
      let(:component_where_parent_has_access_restrict) { result['components'].find { |c| c['ref_ssi'] == ['aspace_72f14d6c32e142baa3eeafdb6e4d69be'] } }
      let(:component_with_access_terms) { result['components'].find { |c| c['ref_ssi'] == ['aspace_72f14d6c32e142baa3eeafdb6e4d69be'] } }
      let(:component_where_parent_has_access_terms) { result['components'].find { |c| c['ref_ssi'] == ['aspace_dba76dab6f750f31aa5fc73e5402e71d'] } }
      let(:component_with_many_parents) { result['components'].find { |c| c['ref_ssi'] == ['aspace_f934f1add34289f28bd0feb478e68275'] } }

      it 'has access restrict' do
        expect(component_with_access_restrict['parent_access_restrict_ssm']).to eq ['Restricted until 2018.']
      end

      it 'gets access restrict from parent if component does not have terms' do
        expect(component_where_parent_has_access_restrict['parent_ssm']).to eq %w[aoa271]
        expect(component_where_parent_has_access_restrict['parent_access_restrict_ssm']).to eq ['No restrictions on access.']
      end

      it 'has access terms' do
        expect(component_with_access_terms['parent_access_terms_ssm']).to eq ['Original photographs must be handled using gloves.']
      end

      it 'gets access terms from parent if component does not have terms' do
        expect(component_where_parent_has_access_terms['parent_ssm']).to eq %w[aoa271]
        expect(component_where_parent_has_access_terms['parent_access_terms_ssm'])
          .to eq ["Copyright was transferred to the public domain. Contact the Reference Staff for details\n        regarding rights."]
      end

      it 'parent_unittitles should be displayable and searchable' do
        component = result['components'].find { |c| c['id'] == ['aoa271aspace_563a320bb37d24a9e1e6f7bf95b52671'] }
        %w[parent_unittitles_ssm parent_unittitles_teim].each do |field|
          expect(component[field]).to contain_exactly(
            'Alpha Omega Alpha Archives, 1894-1992'
          )
        end
      end

      it 'parents are correctly ordered' do
        expect(component_with_many_parents['parent_ssm']).to eq %w[
          aoa271
          aspace_563a320bb37d24a9e1e6f7bf95b52671
          aspace_238a0567431f36f49acea49ef576d408
        ]
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

    it 'only indexes containers at the same level of the component' do
      component = result['components'].find { |c| c['id'] == ['aoa271aspace_563a320bb37d24a9e1e6f7bf95b52671'] }
      expect(component['containers_ssim']).to be_nil
    end
  end

  describe 'subject elements' do
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

    it 'indexes controlaccess subjects within a component' do
      component = result['components'].find { |c| c['id'] == ['aoa271aspace_81c806b82a14c3c79d395bbd383b886f'] }
      %w[access_subjects_ssm access_subjects_ssim].each do |field|
        expect(component).to include field
        expect(component[field]).to contain_exactly 'Minutes'
      end
    end

    context 'with nested controlaccess subject elements' do
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
  end

  describe 'name elements' do
    let(:fixture_path) do
      Arclight::Engine.root.join('spec', 'fixtures', 'ead', 'nlm', 'alphaomegaalpha.xml')
    end

    describe 'collection-level' do
      it 'indexes collection-level <controlaccess> names in their own field' do
        expect(result['names_coll_ssim']).to contain_exactly(
          'Alpha Omega Alpha',
          'Root, William Webster, 1867-1932',
          'Bierring, Walter L. (Walter Lawrence), 1868-1961'
        )
      end

      it 'indexes all names at any level in a shared names field' do
        expect(result['names_ssim']).to include 'Root, William Webster, 1867-1932'
        expect(result['names_ssim']).to include 'Robertson\'s Crab House'
      end
      it 'indexes all names at any level in a type-specific name field' do
        expect(result['persname_ssm']).to include 'Anfinsen, Christian B.'
        expect(result['corpname_ssm']).to include 'Robertson\'s Crab House'
      end
    end

    describe 'component-level' do
      it 'indexes <controlaccess> names in a shared names field' do
        component = result['components'].find { |c| c['id'] == ['aoa271aspace_843e8f9f22bac69872d0802d6fffbb04'] }
        expect(component).to include 'names_ssim'
        expect(component['names_ssim']).to include 'Robertson\'s Crab House'
      end

      it 'indexes names in fields for specific name types, regardless of <controlaccess>' do
        component = result['components'].find { |c| c['id'] == ['aoa271aspace_843e8f9f22bac69872d0802d6fffbb04'] }
        expect(component['corpname_ssm']).to include 'Robertson\'s Crab House'
        expect(component['persname_ssm']).to include 'Anfinsen, Christian B.'
      end
    end
  end

  describe 'geognames' do
    let(:fixture_path) do
      Arclight::Engine.root.join('spec', 'fixtures', 'ead', 'nlm', 'alphaomegaalpha.xml')
    end

    it 'indexes geognames' do
      component = result['components'].find { |d| d['id'] == ['aoa271aspace_843e8f9f22bac69872d0802d6fffbb04'] }
      expect(component).to include 'geogname_sim'
      expect(component['geogname_sim']).to include('Popes Creek (Md.)')

      expect(component).to include 'geogname_ssm'
      expect(component['geogname_ssm']).to include('Popes Creek (Md.)')
    end
  end

  describe 'date ranges' do
    let(:fixture_path) do
      Arclight::Engine.root.join('spec', 'fixtures', 'ead', 'nlm', 'alphaomegaalpha.xml')
    end

    it 'creates date_range_sim' do
      component = result['components'].find { |d| d['id'] == ['aoa271aspace_563a320bb37d24a9e1e6f7bf95b52671'] }
      date_range = component['date_range_sim']
      expect(date_range).to be_an Array
      expect(date_range.length).to eq 75
      expect(date_range.first).to eq 1902
      expect(date_range.last).to eq 1976
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
      expect(result['ead_ssi'].first).to eq 'a0011.xml'
    end

    it 'title' do
      %w[title_ssm title_teim].each do |field|
        expect(result[field]).to include 'Stanford University student life photograph album'
      end
      expect(result['normalized_title_ssm']).to include 'Stanford University student life photograph album, circa 1900-1906'
    end
  end
end
