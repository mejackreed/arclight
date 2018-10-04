# frozen_string_literal: true

module Arclight
  ##
  # A mixin intended to share indexing behavior between
  # the CustomDocument and CustomComponent classes
  module SharedIndexingBehavior
    # @see http://eadiva.com/2/unitdate/
    # @return [YearRange] all of the years between the given years
    def unitdate_for_range
      range = YearRange.new
      return range if normal_unit_dates.blank?
      range << range.parse_ranges(normal_unit_dates)
      range
    end

    def subjects_array(elements, parent:)
      xpath_elements = elements.map { |el| "local-name()='#{el}'" }.join(' or ')
      subjects = search("//#{parent}/controlaccess/*[#{xpath_elements}]").to_a
      clean_facets_array(subjects.flatten.map(&:text))
    end

    def names_array(elements, parent:)
      xpath_elements = elements.map { |el| "local-name()='#{el}'" }.join(' or ')
      names = search("//#{parent}/controlaccess/*[#{xpath_elements}]").to_a
      clean_facets_array(names.flatten.map(&:text))
    end

    # Return a cleaned array of facets without marc subfields
    #
    # E.g. clean_facets_array(
    #        ['FacetValue1 |z FacetValue2','FacetValue3']
    #      ) => ['FacetValue1 -- FacetValue2', 'FacetValue3']
    def clean_facets_array(facets_array)
      Array(facets_array).map { |text| fix_subfield_demarcators(text) }.compact.uniq
    end

    # Replace MARC style subfield demarcators
    #
    # Usage: fix_subfield_demarcators("Subject 1 |z Sub-Subject 2") => "Subject 1 -- Sub-Subject 2"
    def fix_subfield_demarcators(value)
      value.gsub(/\|\w{1}/, '--')
    end

    # Wrap OM's find_by_xpath for convenience
    def search(path)
      find_by_xpath(path) # rubocop:disable DynamicFindBy
    end

    # If a repository slug is provided via an environment variable `REPOSITORY_ID`,
    # then use that to lookup the name rather than the parsed out name from the EAD
    # @param [String] `repository` the default repository name
    def repository_as_configured(repository)
      slug = ENV['REPOSITORY_ID']
      if slug.present?
        begin
          Arclight::Repository.find_by(slug: slug).name
        rescue => e
          raise "The repository slug '#{slug}' was given but it is not found in the Repository configuration data: #{e}"
        end
      else
        repository
      end
    end

    def add_digital_content(prefix:, solr_doc:)
      dao = ng_xml.xpath("#{prefix}/dao").to_a
      return if dao.blank?
      field_name = Solrizer.solr_name('digital_objects', :displayable)
      solr_doc[field_name] = digital_objects(dao)
    end

    def digital_objects(objects)
      objects.map do |dao|
        label = dao.attributes['title'].try(:value) || dao.xpath('daodesc/p').try(:text)
        href = (dao.attributes['href'] || dao.attributes['xlink:href']).try(:value)
        Arclight::DigitalObject.new(label: label, href: href).to_json
      end
    end

    def add_date_ranges(solr_doc)
      Solrizer.insert_field(solr_doc, 'date_range', unitdate_for_range.years, :facetable)
    end

    def add_normalized_title(solr_doc)
      dates = Arclight::NormalizedDate.new(unitdate_inclusive, unitdate_bulk, unitdate_other).to_s
      title = Arclight::NormalizedTitle.new(solr_doc['title_ssm'].try(:first), dates).to_s
      solr_doc['normalized_title_ssm'] = [title]
      solr_doc['normalized_date_ssm'] = [dates]
      title
    end

    def online_content?
      search('//dao[@href]').present?
    end
  end
end
