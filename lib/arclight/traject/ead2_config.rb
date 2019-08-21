# frozen_string_literal: true

require 'traject'
require 'traject/nokogiri_reader'
require 'traject_plus'
require 'traject_plus/macros'
require 'arclight/normalized_date'
require 'arclight/normalized_title'
require 'active_model/conversion' ## Needed for Arclight::Repository
require 'active_support/core_ext/array/wrap'
require 'arclight/digital_object'
require 'arclight/year_range'
require 'arclight/repository'
require 'arclight/traject/nokogiri_namespaceless_reader'

# rubocop:disable Style/MixinUsage
extend TrajectPlus::Macros
# rubocop:enable Style/MixinUsage

settings do
  provide 'reader_class_name', 'NokogiriNamespacelessReader'
  provide 'solr_writer.commit_on_close', 'true'
  provide 'repository', ENV['REPOSITORY_ID']
end

each_record do |_record, context|
  next unless settings['repository']

  context.clipboard[:repository] = Arclight::Repository.find_by(
    slug: settings['repository']
  ).name
end

# Top level
to_field 'id', extract_xpath('//eadid'), strip, gsub('.', '-')
to_field 'title_ssm', extract_xpath('//archdesc/did/unittitle')
to_field 'title_teim', extract_xpath('//archdesc/did/unittitle')
to_field 'ead_ssi' do |_record, accumulator, context|
  accumulator << context.output_hash['id'].first
end

to_field 'level_ssm' do |record, accumulator|
  accumulator << record.at_xpath('//archdesc').attribute('level').value
end

to_field 'level_sim' do |record, accumulator|
  accumulator << record.at_xpath('//archdesc').attribute('level').value&.capitalize
end

to_field 'unitid_ssm', extract_xpath('//archdesc/did/unitid')

to_field 'unitdate_bulk_ssim', extract_xpath('//archdesc/did/unitdate[@type="bulk"]')
to_field 'unitdate_inclusive_ssim', extract_xpath('//archdesc/did/unitdate[@type="inclusive"]')
to_field 'unitdate_other_ssim', extract_xpath('//archdesc/did/unitdate[not(@type)]')

to_field 'normalized_title_ssm' do |_record, accumulator, context|
  dates = Arclight::NormalizedDate.new(
    context.output_hash['unitdate_inclusive_ssim'],
    context.output_hash['unitdate_bulk_ssim'],
    context.output_hash['unitdate_other_ssim']
  ).to_s
  title = context.output_hash['title_ssm'].first
  accumulator << Arclight::NormalizedTitle.new(title, dates).to_s
end

to_field 'normalized_date_ssm' do |_record, accumulator, context|
  accumulator << Arclight::NormalizedDate.new(
    context.output_hash['unitdate_inclusive_ssim'],
    context.output_hash['unitdate_bulk_ssim'],
    context.output_hash['unitdate_other_ssim']
  ).to_s
end

to_field 'repository_ssm' do |_record, accumulator, context|
  accumulator << context.clipboard[:repository]
end

to_field 'repository_sim' do |_record, accumulator, context|
  accumulator << context.clipboard[:repository]
end

to_field 'geogname_ssm', extract_xpath('//archdesc/controlaccess/geogname')

to_field 'geogname_sim', extract_xpath('//archdesc/controlaccess/geogname')

to_field 'creator_ssm', extract_xpath("//archdesc/did/origination[@label='creator']")
to_field 'creator_ssim', extract_xpath("//archdesc/did/origination[@label='creator']")
to_field 'creator_sort' do |record, accumulator|
  accumulator << record.xpath("//archdesc/did/origination[@label='creator']").map { |c| c.text.strip }.join(', ')
end

to_field 'creator_persname_ssm', extract_xpath("//archdesc/did/origination[@label='creator']/persname")
to_field 'creator_persname_ssim', extract_xpath("//archdesc/did/origination[@label='creator']/persname")
to_field 'creator_corpname_ssm', extract_xpath("//archdesc/did/origination[@label='creator']/corpname")
to_field 'creator_corpname_ssim', extract_xpath("//archdesc/did/origination[@label='creator']/corpname")
to_field 'creator_famname_ssm', extract_xpath("//archdesc/did/origination[@label='creator']/famname")
to_field 'creator_famname_ssim', extract_xpath("//archdesc/did/origination[@label='creator']/famname")

to_field 'creators_ssim' do |_record, accumulator, context|
  accumulator.concat context.output_hash['creator_persname_ssm'] if context.output_hash['creator_persname_ssm']
  accumulator.concat context.output_hash['creator_corpname_ssm'] if context.output_hash['creator_corpname_ssm']
  accumulator.concat context.output_hash['creator_famname_ssm'] if context.output_hash['creator_famname_ssm']
end

to_field 'places_ssim', extract_xpath('//archdesc/controlaccess/geogname')

# Indexes only specified controlled terms for archival description into the access_subject field
to_field 'access_subjects_ssim', extract_xpath('//archdesc/controlaccess', to_text: false) do |_record, accumulator|
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

# Each component child document
# <c> <c01> <c12>
compose 'components', ->(record, accumulator, _context) { accumulator.concat record.xpath('//*[is_component(.)]', NokogiriXpathExtensions.new) } do
  to_field 'ref_ssi' do |record, accumulator|
    accumulator << record.attribute('id')&.value&.strip&.gsub('.', '-')
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
    accumulator << context.output_hash['id'].first
  end

  to_field 'title_ssm', extract_xpath('./did/unittitle')
  to_field 'title_teim', extract_xpath('./did/unittitle')

  to_field 'unitdate_bulk_ssim', extract_xpath('./did/unitdate[@type="bulk"]')
  to_field 'unitdate_inclusive_ssim', extract_xpath('./did/unitdate[@type="inclusive"]')
  to_field 'unitdate_other_ssim', extract_xpath('./did/unitdate[not(@type)]')

  to_field 'normalized_title_ssm' do |_record, accumulator, context|
    dates = Arclight::NormalizedDate.new(
      context.output_hash['unitdate_inclusive_ssim'],
      context.output_hash['unitdate_bulk_ssim'],
      context.output_hash['unitdate_other_ssim']
    ).to_s
    title = context.output_hash['title_ssm'].first
    accumulator << Arclight::NormalizedTitle.new(title, dates).to_s
  end

  to_field 'normalized_date_ssm' do |_record, accumulator, context|
    accumulator << Arclight::NormalizedDate.new(
      context.output_hash['unitdate_inclusive_ssim'],
      context.output_hash['unitdate_bulk_ssim'],
      context.output_hash['unitdate_other_ssim']
    ).to_s
  end

  to_field 'component_level_isim' do |record, accumulator|
    accumulator << 1 + record.ancestors.count { |node| node.name == 'c' }
  end

  to_field 'parent_ssm' do |record, accumulator, context|
    accumulator << context.clipboard[:parent].output_hash['id'].first
    accumulator.concat NokogiriXpathExtensions.new.is_component(record.ancestors).map { |n| n.attribute('id').value }
  end

  to_field 'parent_ssi' do |_record, accumulator, context|
    accumulator << context.output_hash['parent_ssm'].last
  end

  to_field 'parent_unittitles_ssm' do |_record, accumulator, context|
    ## Top level document
    accumulator.concat context.clipboard[:parent].output_hash['normalized_title_ssm']
    ## Other components
    context.output_hash['parent_ssm']&.drop(1)&.each do |id|
      accumulator.concat Array
        .wrap(context.clipboard[:parent].output_hash['components'])
        .find { |c| c['ref_ssi'] == [id] }&.[]('normalized_title_ssm')
    end
  end

  to_field 'unitid_ssm', extract_xpath('./did/unitid')
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

  to_field 'extent_ssm', extract_xpath('./did/physdesc/extent')
  to_field 'abstract_ssm', extract_xpath('./did/abstract')
  to_field 'scopecontent_ssm', extract_xpath('./scopecontent/p')
  to_field 'creator_ssm', extract_xpath("./did/origination[@label='creator']")
  to_field 'creator_ssim', extract_xpath("./did/origination[@label='creator']")
  to_field 'creators_ssim', extract_xpath("./did/origination[@label='creator']")
  to_field 'creator_sort' do |record, accumulator|
    accumulator << record.xpath("./did/origination[@label='creator']").map(&:text).join(', ')
  end
  to_field 'collection_creator_ssm' do |_record, accumulator, context|
    accumulator.concat Array.wrap(context.clipboard[:parent].output_hash['creator_ssm'])
  end
  to_field 'has_online_content_ssim', extract_xpath('//dao') do |_record, accumulator|
    accumulator.replace([accumulator.any?])
  end
  to_field 'child_component_count_isim', extract_xpath('c') do |_record, accumulator|
    accumulator.replace([accumulator.length])
  end

  to_field 'ref_ssm' do |record, accumulator|
    accumulator << record.attribute('id')
  end

  to_field 'level_ssm' do |record, accumulator|
    accumulator << record.attribute('level')
  end

  to_field 'level_sim' do |record, accumulator|
    accumulator << record.attribute('level')
  end
  to_field 'userestrict_ssm', extract_xpath('userestrict/p')
  # to_field 'parent_access_restrict_ssm'
  # to_field 'parent_access_terms_ssm'
  to_field 'digital_objects_ssm', extract_xpath('//dao') do |record, accumulator|
    digital_objects = record.xpath('//dao').map do |dao|
      label = dao.attributes['title']&.value || dao.xpath('daodesc/p')&.text
      href = (dao.attributes['href'] || dao.attributes['xlink:href'])&.value
      object = Arclight::DigitalObject.new(label: label, href: href)
      object.to_json
    end

    accumulator.replace(digital_objects.to_a)
  end

  to_field 'date_range_sim', extract_xpath('./did/unitdate/@normal') do |_record, accumulator|
    range = Arclight::YearRange.new
    next range.years if accumulator.blank?

    range << range.parse_ranges(accumulator)
    accumulator.replace range.years
  end

  # to_field 'names_ssim'
  to_field 'geogname_sim', extract_xpath('./controlaccess/geogname')
  to_field 'geogname_ssm', extract_xpath('./controlaccess/geogname')
  to_field 'places_ssim', extract_xpath('controlaccess/geogname')

  # Indexes only specified controlled terms for archival description into the access_subject field
  to_field 'access_subjects_ssim', extract_xpath('./controlaccess', to_text: false) do |_record, accumulator|
    accumulator.map! do |element|
      %w[subject function occupation genreform].map do |selector|
        element.xpath(".//#{selector}").map(&:text)
      end
    end.flatten!
  end

  to_field 'access_subjects_ssm' do |_record, accumulator, context|
    accumulator.concat Array.wrap(context.output_hash['access_subjects_ssim'])
  end

  to_field 'language_ssm', extract_xpath('did/langmaterial')
  to_field 'accessrestrict_ssm', extract_xpath('accessrestrict/*[local-name()!="head"]')
  to_field 'prefercite_ssm', extract_xpath('prefercite/*[local-name()!="head"]')
  to_field 'containers_ssim' do |record, accumulator|
    record.xpath('//container').each do |node|
      accumulator << [node.attribute('type'), node.text].join(' ').strip
    end
  end
  to_field 'bioghist_ssm', extract_xpath('bioghist/*[local-name()!="head"]')
  to_field 'acqinfo_ssm', extract_xpath('acqinfo/*[local-name()!="head"]')
  to_field 'relatedmaterial_ssm', extract_xpath('relatedmaterial/*[local-name()!="head"]')
  to_field 'separatedmaterial_ssm', extract_xpath('separatedmaterial/*[local-name()!="head"]')
  to_field 'otherfindaid_ssm', extract_xpath('otherfindaid/*[local-name()!="head"]')
  to_field 'altformavail_ssm', extract_xpath('altformavail/*[local-name()!="head"]')
  to_field 'originalsloc_ssm', extract_xpath('originalsloc/*[local-name()!="head"]')
  # to_field 'names_coll_ssim'
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
