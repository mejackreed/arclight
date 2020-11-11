# frozen_string_literal: true

require 'logger'
require 'traject'
require 'traject/nokogiri_reader'
require 'traject_plus'
require 'traject_plus/macros'
require 'arclight/level_label'
require 'arclight/normalized_date'
require 'arclight/normalized_title'
require 'active_model/conversion' ## Needed for Arclight::Repository
require 'active_support/core_ext/array/wrap'
require 'arclight/digital_object'
require 'arclight/year_range'
require 'arclight/repository'
require 'arclight/missing_id_strategy'
require 'arclight/traject/nokogiri_namespaceless_reader'

# rubocop:disable Style/MixinUsage
extend TrajectPlus::Macros
# rubocop:enable Style/MixinUsage

NAME_ELEMENTS = %w[corpname famname name persname].freeze

SEARCHABLE_NOTES_FIELDS = %w[
  accessrestrict
  accruals
  altformavail
  appraisal
  arrangement
  bibliography
  bioghist
  custodhist
  fileplan
  note
  odd
  originalsloc
  otherfindaid
  phystech
  prefercite
  processinfo
  relatedmaterial
  scopecontent
  separatedmaterial
  userestrict
].freeze

DID_SEARCHABLE_NOTES_FIELDS = %w[
  abstract
  materialspec
  physloc
].freeze

settings do
  provide 'reader_class_name', 'Arclight::Traject::NokogiriNamespacelessReader'
  provide 'solr_writer.commit_on_close', 'true'
  provide 'repository', ENV['REPOSITORY_ID']
  provide 'logger', Logger.new($stderr)
end

each_record do |_record, context|
  next unless settings['repository']

  context.clipboard[:repository] = Arclight::Repository.find_by(
    slug: settings['repository']
  ).name
end

# ==================
# Top level document
# ==================

to_field 'id', extract_xpath('/ead/eadheader/eadid'), strip, gsub('.', '-')
to_field 'title_filing_si', extract_xpath('/ead/eadheader/filedesc/titlestmt/titleproper[@type="filing"]')
to_field 'title_ssm', extract_xpath('/ead/archdesc/did/unittitle')
to_field 'title_teim', extract_xpath('/ead/archdesc/did/unittitle')
to_field 'ead_ssi', extract_xpath('/ead/eadheader/eadid')

to_field 'unitdate_ssm', extract_xpath('/ead/archdesc/did/unitdate')
to_field 'unitdate_bulk_ssim', extract_xpath('/ead/archdesc/did/unitdate[@type="bulk"]')
to_field 'unitdate_inclusive_ssm', extract_xpath('/ead/archdesc/did/unitdate[@type="inclusive"]')
to_field 'unitdate_other_ssim', extract_xpath('/ead/archdesc/did/unitdate[not(@type)]')

# All top-level docs treated as 'collection' for routing / display purposes
to_field 'level_ssm' do |_record, accumulator|
  accumulator << 'collection'
end

# Keep the original top-level archdesc/@level for Level facet in addition to 'Collection'
to_field 'level_sim' do |record, accumulator|
  level = record.at_xpath('/ead/archdesc').attribute('level')&.value
  other_level = record.at_xpath('/ead/archdesc').attribute('otherlevel')&.value

  accumulator << Arclight::LevelLabel.new(level, other_level).to_s
  accumulator << 'Collection' unless level == 'collection'
end

to_field 'unitid_ssm', extract_xpath('/ead/archdesc/did/unitid')
to_field 'unitid_teim', extract_xpath('/ead/archdesc/did/unitid')
to_field 'collection_unitid_ssm', extract_xpath('/ead/archdesc/did/unitid')

to_field 'normalized_title_ssm' do |_record, accumulator, context|
  dates = Arclight::NormalizedDate.new(
    context.output_hash['unitdate_inclusive_ssm'],
    context.output_hash['unitdate_bulk_ssim'],
    context.output_hash['unitdate_other_ssim']
  ).to_s
  title = context.output_hash['title_ssm'].first
  accumulator << Arclight::NormalizedTitle.new(title, dates).to_s
end

to_field 'normalized_date_ssm' do |_record, accumulator, context|
  accumulator << Arclight::NormalizedDate.new(
    context.output_hash['unitdate_inclusive_ssm'],
    context.output_hash['unitdate_bulk_ssim'],
    context.output_hash['unitdate_other_ssim']
  ).to_s
end

to_field 'collection_ssm' do |_record, accumulator, context|
  accumulator.concat context.output_hash.fetch('normalized_title_ssm', [])
end
to_field 'collection_sim' do |_record, accumulator, context|
  accumulator.concat context.output_hash.fetch('normalized_title_ssm', [])
end
to_field 'collection_ssi' do |_record, accumulator, context|
  accumulator.concat context.output_hash.fetch('normalized_title_ssm', [])
end
to_field 'collection_title_tesim' do |_record, accumulator, context|
  accumulator.concat context.output_hash.fetch('normalized_title_ssm', [])
end

to_field 'repository_ssm' do |_record, accumulator, context|
  accumulator << context.clipboard[:repository]
end

to_field 'repository_sim' do |_record, accumulator, context|
  accumulator << context.clipboard[:repository]
end

to_field 'geogname_ssm', extract_xpath('/ead/archdesc/controlaccess/geogname')
to_field 'geogname_sim', extract_xpath('/ead/archdesc/controlaccess/geogname')

to_field 'creator_ssm', extract_xpath('/ead/archdesc/did/origination')
to_field 'creator_sim', extract_xpath('/ead/archdesc/did/origination')
to_field 'creator_ssim', extract_xpath('/ead/archdesc/did/origination')
to_field 'creator_sort' do |record, accumulator|
  accumulator << record.xpath('/ead/archdesc/did/origination').map { |c| c.text.strip }.join(', ')
end

to_field 'creator_persname_ssm', extract_xpath('/ead/archdesc/did/origination/persname')
to_field 'creator_persname_ssim', extract_xpath('/ead/archdesc/did/origination/persname')
to_field 'creator_corpname_ssm', extract_xpath('/ead/archdesc/did/origination/corpname')
to_field 'creator_corpname_sim', extract_xpath('/ead/archdesc/did/origination/corpname')
to_field 'creator_corpname_ssim', extract_xpath('/ead/archdesc/did/origination/corpname')
to_field 'creator_famname_ssm', extract_xpath('/ead/archdesc/did/origination/famname')
to_field 'creator_famname_ssim', extract_xpath('/ead/archdesc/did/origination/famname')

to_field 'persname_sim', extract_xpath('//persname')

to_field 'creators_ssim' do |_record, accumulator, context|
  accumulator.concat context.output_hash['creator_persname_ssm'] if context.output_hash['creator_persname_ssm']
  accumulator.concat context.output_hash['creator_corpname_ssm'] if context.output_hash['creator_corpname_ssm']
  accumulator.concat context.output_hash['creator_famname_ssm'] if context.output_hash['creator_famname_ssm']
end

to_field 'places_sim', extract_xpath('/ead/archdesc/controlaccess/geogname')
to_field 'places_ssim', extract_xpath('/ead/archdesc/controlaccess/geogname')
to_field 'places_ssm', extract_xpath('/ead/archdesc/controlaccess/geogname')

to_field 'access_terms_ssm', extract_xpath('/ead/archdesc/userestrict/*[local-name()!="head"]')

to_field 'acqinfo_ssim', extract_xpath('/ead/archdesc/acqinfo/*[local-name()!="head"]')
to_field 'acqinfo_ssim', extract_xpath('/ead/archdesc/descgrp/acqinfo/*[local-name()!="head"]')

to_field 'access_subjects_ssim', extract_xpath('/ead/archdesc/controlaccess', to_text: false) do |_record, accumulator|
  accumulator.map! do |element|
    %w[subject function occupation genreform].map do |selector|
      element.xpath(".//#{selector}").map(&:text)
    end
  end.flatten!
end

to_field 'access_subjects_ssm' do |_record, accumulator, context|
  accumulator.concat Array.wrap(context.output_hash['access_subjects_ssim'])
end

to_field 'has_online_content_ssim', extract_xpath('.//dao') do |_record, accumulator|
  accumulator.replace([accumulator.any?])
end

to_field 'digital_objects_ssm', extract_xpath('/ead/archdesc/did/dao|/ead/archdesc/dao', to_text: false) do |_record, accumulator|
  accumulator.map! do |dao|
    label = dao.attributes['title']&.value ||
            dao.xpath('daodesc/p')&.text
    href = (dao.attributes['href'] || dao.attributes['xlink:href'])&.value
    Arclight::DigitalObject.new(label: label, href: href).to_json
  end
end

to_field 'extent_ssm', extract_xpath('/ead/archdesc/did/physdesc/extent')
to_field 'extent_teim', extract_xpath('/ead/archdesc/did/physdesc/extent')
to_field 'genreform_sim', extract_xpath('/ead/archdesc/controlaccess/genreform')
to_field 'genreform_ssm', extract_xpath('/ead/archdesc/controlaccess/genreform')

to_field 'date_range_sim', extract_xpath('/ead/archdesc/did/unitdate/@normal', to_text: false) do |_record, accumulator|
  range = Arclight::YearRange.new
  next range.years if accumulator.blank?

  ranges = accumulator.map(&:to_s)
  range << range.parse_ranges(ranges)
  accumulator.replace range.years
end

SEARCHABLE_NOTES_FIELDS.map do |selector|
  to_field "#{selector}_tesim", extract_xpath("/ead/archdesc/#{selector}/*[local-name()!='head']", to_text: false)
  to_field "#{selector}_heading_ssm", extract_xpath("/ead/archdesc/#{selector}/head") unless selector == 'prefercite'
  to_field "#{selector}_teim", extract_xpath("/ead/archdesc/#{selector}/*[local-name()!='head']")
end

DID_SEARCHABLE_NOTES_FIELDS.map do |selector|
  to_field "#{selector}_tesim", extract_xpath("/ead/archdesc/did/#{selector}", to_text: false)
end

NAME_ELEMENTS.map do |selector|
  to_field 'names_coll_ssim', extract_xpath("/ead/archdesc/controlaccess/#{selector}")
  to_field 'names_ssim', extract_xpath("//#{selector}")
  to_field "#{selector}_ssm", extract_xpath("//#{selector}")
end

to_field 'corpname_sim', extract_xpath('//corpname')

to_field 'language_sim', extract_xpath('/ead/archdesc/did/langmaterial')
to_field 'language_ssm', extract_xpath('/ead/archdesc/did/langmaterial')

to_field 'descrules_ssm', extract_xpath('/ead/eadheader/profiledesc/descrules')

# =============================
# Each component child document
# <c> <c01> <c12>
# =============================

compose 'components', ->(record, accumulator, _context) { accumulator.concat record.xpath('//*[is_component(.)]', NokogiriXpathExtensions.new) } do
  to_field 'ref_ssi' do |record, accumulator, context|
    accumulator <<  if record.attribute('id').blank?
                     strategy = Arclight::MissingIdStrategy.selected
                     hexdigest = strategy.new(record).to_hexdigest
                     parent_id = context.clipboard[:parent].output_hash['id'].first
                     logger.warn('MISSING ID WARNING') do
                       [
                   #      "A component in #{parent_id} did not have an ID so one was minted using the #{strategy} strategy.",
                         "The ID of this document will be #{parent_id}#{hexdigest}."
                       ].join(' ')
                     end
                     record['id'] = hexdigest
                     hexdigest
                   else
            #         record.attribute('id')&.value&.strip&.gsub('.', '-')

                     strategy = Arclight::MissingIdStrategy.selected
                     hexdigest = strategy.new(record).to_hexdigest
                     parent_id = context.clipboard[:parent].output_hash['id'].first
                     logger.warn('MISSING ID WARNING') do
                       [
                   #      "A component in #{parent_id} did not have an ID so one was minted using the #{strategy} strategy.",
                         "The ID of this document will be #{parent_id}#{hexdigest}."
                       ].join(' ')
                     end
                     record['id'] = hexdigest
                     hexdigest
                   end
  end

  to_field 'ref_ssm' do |_record, accumulator, context|
    accumulator.concat context.output_hash['ref_ssi']
  end

  to_field 'id' do |_record, accumulator, context|
    accumulator << [
      context.clipboard[:parent].output_hash['id'],
      context.output_hash['ref_ssi']
    ].join('')
  end

  to_field 'ead_ssi' do |_record, accumulator, context|
    accumulator << context.clipboard[:parent].output_hash['ead_ssi'].first
  end

  to_field 'title_filing_si', extract_xpath('./did/unittitle'), first_only
  to_field 'title_ssm', extract_xpath('./did/unittitle')
  to_field 'title_teim', extract_xpath('./did/unittitle')

  to_field 'unitdate_bulk_ssim', extract_xpath('./did/unitdate[@type="bulk"]')
  to_field 'unitdate_inclusive_ssm', extract_xpath('./did/unitdate[@type="inclusive"]')
  to_field 'unitdate_other_ssim', extract_xpath('./did/unitdate[not(@type)]')

  to_field 'normalized_title_ssm' do |_record, accumulator, context|
    dates = Arclight::NormalizedDate.new(
      context.output_hash['unitdate_inclusive_ssm'],
      context.output_hash['unitdate_bulk_ssim'],
      context.output_hash['unitdate_other_ssim']
    ).to_s
    title = context.output_hash['title_ssm']&.first
    accumulator << Arclight::NormalizedTitle.new(title, dates).to_s
  end

  to_field 'normalized_date_ssm' do |_record, accumulator, context|
    accumulator << Arclight::NormalizedDate.new(
      context.output_hash['unitdate_inclusive_ssm'],
      context.output_hash['unitdate_bulk_ssim'],
      context.output_hash['unitdate_other_ssim']
    ).to_s
  end

  to_field 'component_level_isim' do |record, accumulator|
    accumulator << 1 + NokogiriXpathExtensions.new.is_component(record.ancestors).count
  end

  to_field 'parent_ssim' do |record, accumulator, context|
    accumulator << context.clipboard[:parent].output_hash['id'].first
    accumulator.concat NokogiriXpathExtensions.new.is_component(record.ancestors).reverse.map { |n| n.attribute('id')&.value }
  end

  to_field 'parent_ssi' do |_record, accumulator, context|
    accumulator << context.output_hash['parent_ssim'].last
  end

  to_field 'parent_unittitles_ssm' do |_rec, accumulator, context|
    # top level document
    accumulator.concat context.clipboard[:parent].output_hash['normalized_title_ssm']
    parent_ssim = context.output_hash['parent_ssim']
    components = context.clipboard[:parent].output_hash['components']

    # other components
    if parent_ssim && components
      ancestors = parent_ssim.drop(1).map { |x| [x] }
      accumulator.concat components.select { |c| ancestors.include? c['ref_ssi'] }.flat_map { |c| c['normalized_title_ssm'] }
    end
  end

  to_field 'parent_unittitles_teim' do |_record, accumulator, context|
    accumulator.concat context.output_hash['parent_unittitles_ssm']
  end

  to_field 'parent_levels_ssm' do |_record, accumulator, context|
    ## Top level document
    accumulator.concat context.clipboard[:parent].output_hash['level_ssm']
    ## Other components
    context.output_hash['parent_ssim']&.drop(1)&.each do |id|
      accumulator.concat Array
        .wrap(context.clipboard[:parent].output_hash['components'])
        .select { |c| c['ref_ssi'] == [id] }.map { |c| c['level_ssm'] }.flatten
    end
  end

  to_field 'unitid_ssm', extract_xpath('./did/unitid')
  to_field 'collection_unitid_ssm' do |_record, accumulator, context|
    accumulator.concat Array.wrap(context.clipboard[:parent].output_hash['unitid_ssm'])
  end
  to_field 'repository_ssm' do |_record, accumulator, context|
    accumulator << context.clipboard[:parent].clipboard[:repository]
  end
  to_field 'repository_sim' do |_record, accumulator, context|
    accumulator << context.clipboard[:parent].clipboard[:repository]
  end
  to_field 'collection_ssm' do |_record, accumulator, context|
    accumulator.concat context.clipboard[:parent].output_hash['normalized_title_ssm']
  end
  to_field 'collection_sim' do |_record, accumulator, context|
    accumulator.concat context.clipboard[:parent].output_hash['normalized_title_ssm']
  end
  to_field 'collection_ssi' do |_record, accumulator, context|
    accumulator.concat context.clipboard[:parent].output_hash['normalized_title_ssm']
  end

  to_field 'extent_ssm', extract_xpath('./did/physdesc/extent')
  to_field 'extent_teim', extract_xpath('./did/physdesc/extent')

  to_field 'creator_ssm', extract_xpath('./did/origination')
  to_field 'creator_ssim', extract_xpath('./did/origination')
  to_field 'creators_ssim', extract_xpath('./did/origination')
  to_field 'creator_sort' do |record, accumulator|
    accumulator << record.xpath('./did/origination').map(&:text).join(', ')
  end
  to_field 'collection_creator_ssm' do |_record, accumulator, context|
    accumulator.concat Array.wrap(context.clipboard[:parent].output_hash['creator_ssm'])
  end
  to_field 'has_online_content_ssim', extract_xpath('.//dao') do |_record, accumulator|
    accumulator.replace([accumulator.any?])
  end
  to_field 'child_component_count_isim' do |record, accumulator|
    accumulator << NokogiriXpathExtensions.new.is_component(record.children).count
  end

  to_field 'ref_ssm' do |record, accumulator|
    accumulator << record.attribute('id')
  end

  to_field 'level_ssm' do |record, accumulator|
    level = record.attribute('level')&.value
    other_level = record.attribute('otherlevel')&.value
    accumulator << Arclight::LevelLabel.new(level, other_level).to_s
  end

  to_field 'level_sim' do |_record, accumulator, context|
    next unless context.output_hash['level_ssm']

    accumulator.concat context.output_hash['level_ssm']&.map(&:capitalize)
  end

  to_field 'sort_ii' do |_record, accumulator, context|
    accumulator.replace([context.position])
  end

  # Get the <accessrestrict> from the closest ancestor that has one (includes top-level)
  to_field 'parent_access_restrict_ssm' do |record, accumulator|
    accumulator.concat Array
      .wrap(record.xpath('(./ancestor::*/accessrestrict)[last()]/*[local-name()!="head"]')
      .map(&:text))
  end

  # Get the <userestrict> from self OR the closest ancestor that has one (includes top-level)
  to_field 'parent_access_terms_ssm' do |record, accumulator|
    accumulator.concat Array
      .wrap(record.xpath('(./ancestor-or-self::*/userestrict)[last()]/*[local-name()!="head"]')
      .map(&:text))
  end

  to_field 'digital_objects_ssm', extract_xpath('./dao|./did/dao', to_text: false) do |_record, accumulator|
    accumulator.map! do |dao|
      label = dao.attributes['title']&.value ||
              dao.xpath('daodesc/p')&.text
      href = (dao.attributes['href'] || dao.attributes['xlink:href'])&.value
      Arclight::DigitalObject.new(label: label, href: href).to_json
    end
  end

  to_field 'date_range_sim', extract_xpath('./did/unitdate/@normal', to_text: false) do |_record, accumulator|
    range = Arclight::YearRange.new
    next range.years if accumulator.blank?

    ranges = accumulator.map(&:to_s)
    range << range.parse_ranges(ranges)
    accumulator.replace range.years
  end

  NAME_ELEMENTS.map do |selector|
    to_field 'names_ssim', extract_xpath("./controlaccess/#{selector}")
    to_field "#{selector}_ssm", extract_xpath(".//#{selector}")
  end

  to_field 'geogname_sim', extract_xpath('./controlaccess/geogname')
  to_field 'geogname_ssm', extract_xpath('./controlaccess/geogname')
  to_field 'places_ssim', extract_xpath('./controlaccess/geogname')

  to_field 'access_subjects_ssim', extract_xpath('./controlaccess', to_text: false) do |_record, accumulator|
    accumulator.map! do |element|
      %w[subject function occupation genreform].map do |selector|
        element.xpath(".//#{selector}").map(&:text)
      end
    end.flatten!
  end

  to_field 'access_subjects_ssm' do |_record, accumulator, context|
    accumulator.concat(context.output_hash.fetch('access_subjects_ssim', []))
  end

  to_field 'acqinfo_ssim', extract_xpath('/ead/archdesc/acqinfo/*[local-name()!="head"]')
  to_field 'acqinfo_ssim', extract_xpath('/ead/archdesc/descgrp/acqinfo/*[local-name()!="head"]')
  to_field 'acqinfo_ssim', extract_xpath('./acqinfo/*[local-name()!="head"]')
  to_field 'acqinfo_ssim', extract_xpath('./descgrp/acqinfo/*[local-name()!="head"]')

  to_field 'language_ssm', extract_xpath('./did/langmaterial')
  to_field 'containers_ssim' do |record, accumulator|
    record.xpath('./did/container').each do |node|
      accumulator << [node.attribute('type'), node.text].join(' ').strip
    end
  end

  SEARCHABLE_NOTES_FIELDS.map do |selector|
    to_field "#{selector}_ssm", extract_xpath("./#{selector}/*[local-name()!='head']", to_text: false)
    to_field "#{selector}_heading_ssm", extract_xpath("./#{selector}/head")
    to_field "#{selector}_teim", extract_xpath("./#{selector}/*[local-name()!='head']")
  end
  DID_SEARCHABLE_NOTES_FIELDS.map do |selector|
    to_field "#{selector}_ssm", extract_xpath("./did/#{selector}", to_text: false)
  end
  to_field 'did_note_ssm', extract_xpath('./did/note')
end

each_record do |_record, context|
  context.output_hash['components'] &&= context.output_hash['components'].select { |c| c.keys.any? }
end

##
# Used for evaluating xpath components to find
class NokogiriXpathExtensions
  # rubocop:disable Naming/PredicateName, Style/FormatString
  def is_component(node_set)
    node_set.find_all do |node|
      component_elements = (1..12).map { |i| "c#{'%02d' % i}" }
      component_elements.push 'c'
      component_elements.include? node.name
    end
  end
  # rubocop:enable Naming/PredicateName, Style/FormatString
end
