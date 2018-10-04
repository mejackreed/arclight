# frozen_string_literal: true

module Arclight
  ##
  # An module to extend SolrEad::Indexer behaviors to allow us to add
  # or override behaviors that require knowledge of the entire XML document.
  module SolrEadIndexerExt
    def additional_component_fields(node, addl_fields = {})
      solr_doc = super

      add_count_of_child_compontents(node, solr_doc)
      add_ancestral_titles(node, solr_doc)
      add_ancestral_ids(node, solr_doc)

      add_collection_creator_to_component(node, solr_doc)

      add_self_or_parents_restrictions(node, solr_doc)

      add_self_or_parents_terms(node, solr_doc)

      solr_doc
    end

    def delete_all
      solr.delete_by_query('*:*')
      solr.commit
    end

    private

    # Note that we need to redo what solr_ead does for ids due to our normalization process
    def add_ancestral_ids(node, solr_doc)
      @parent_id_name ||= Solrizer.solr_name('parent', :stored_sortable)
      @parent_ids_field_name ||= Solrizer.solr_name('parent', :displayable)
      @parent_ids_search_field_name ||= Solrizer.solr_name('parent', :searchable)

      ids = ancestral_ids(node)
      solr_doc[@parent_ids_field_name] = ids
      solr_doc[@parent_ids_search_field_name] = ids
      solr_doc[@parent_id_name] = ids.last
    end

    # Note that we need to redo what solr_ead does for titles due to our normalization process
    def add_ancestral_titles(node, solr_doc)
      @parent_titles_field_name ||= Solrizer.solr_name('parent_unittitles', :displayable)
      @parent_titles_search_field_name ||= Solrizer.solr_name('parent_unittitles', :searchable)
      @collection_facet_name ||= Solrizer.solr_name('collection', :facetable)
      @collection_name ||= Solrizer.solr_name('collection', :displayable)

      titles = ancestral_titles(node)
      solr_doc[@parent_titles_field_name] = titles
      solr_doc[@parent_titles_search_field_name] = titles
      solr_doc[@collection_name] = [titles.first] # collection is always on top
      solr_doc[@collection_facet_name] = [titles.first]
    end

    def add_count_of_child_compontents(node, solr_doc)
      @child_component_count_name ||= Solrizer.solr_name('child_component_count', type: :integer)

      solr_doc[@child_component_count_name] = node.xpath('count(c)').to_i
    end

    def ancestral_ids(node)
      ancestral_visit(node, :normalized_component_id, :normalized_collection_id)
    end

    def ancestral_titles(node)
      ancestral_visit(node, :normalized_component_title, :normalized_collection_title)
    end

    # visit each component's parent and finish with a visit on the collection
    def ancestral_visit(node, component_fn, collection_fn, results = [])
      while node.parent && node.parent.name == 'c'
        parent = node.parent
        results << send(component_fn, parent)
        node = parent
      end
      results << send(collection_fn, node)
      results.reverse
    end

    def normalized_component_title(node)
      data = extract_title_and_dates(node)
      normalize_title(data)
    end

    def normalized_collection_title(node)
      data = extract_title_and_dates(node, '//archdesc/')
      normalize_title(data)
    end

    def normalize_title(data)
      Arclight::NormalizedTitle.new(
        data[:title],
        Arclight::NormalizedDate.new(
          data[:unitdate_inclusive],
          data[:unitdate_bulk],
          data[:unitdate_other]
        ).to_s
      ).to_s
    end

    # TODO: these xpaths should be DRY'd up -- they're in both terminologies
    def extract_title_and_dates(node, prefix = nil)
      data = {
        unitdate_inclusive: [],
        unitdate_bulk: [],
        unitdate_other: []
      }
      data[:title] = node.xpath("#{prefix}did/unittitle").text if node.xpath("#{prefix}did/unittitle")
      node.xpath("#{prefix}did/unitdate[@type=\"inclusive\"]").each do |unitdate|
        if unitdate.attr("type").downcase  == "inclusive"
          data[:unitdate_inclusive] << unitdate.text if unitdate
        elsif unitdate.attr("type").downcase  == "bulk"
          data[:unitdate_bulk] << unitdate.text if unitdate
        else
          data[:unitdate_other] << unitdate.text if unitdate
        end
      end
      data
    end

    def normalized_component_id(node)
      Arclight::NormalizedId.new(node['id'].to_s).to_s
    end

    def normalized_collection_id(node)
      Arclight::NormalizedId.new(node.document.at_xpath('//eadid').text).to_s
    end

    # This mimics similar behavior in Arclight::CustomDocument
    def add_collection_creator_to_component(node, solr_doc)
      field_name = Solrizer.solr_name('collection_creator', :displayable)
      repository = solr_doc[Solrizer.solr_name('repository', :displayable)]
      creators = node.xpath('//archdesc/did/origination[@label="creator"]/*/text()').map(&:text)
      solr_doc[field_name] = creators - [repository]
    end

    def parent_check_list(node, root_path, element_path, results = [])
      orginal_node = node
      results = node.xpath("#{root_path}/#{element_path}").map(&:text)
      # if current restriction return, else go up to parent and check
      while node.parent.name == 'c' && results.blank?
        parent = node.parent
        results = parent.xpath("#{root_path}/#{element_path}").map(&:text)
        node = parent
      end
      # If no parental results, check the collection
      results = orginal_node.xpath("//archdesc/#{element_path}").map(&:text) if results.blank?
      results.flatten # can't use with flatten! because that returns nil
    end

    def add_self_or_parents_restrictions(node, solr_doc)
      field_name = Solrizer.solr_name('parent_access_restrict', :displayable)
      solr_doc[field_name] = parent_check_list(node, './', 'accessrestrict/p/text()')
      solr_doc[field_name]
    end

    def add_self_or_parents_terms(node, solr_doc)
      field_name = Solrizer.solr_name('parent_access_terms', :displayable)
      solr_doc[field_name] = parent_check_list(node, './', 'userestrict/p/text()')
      solr_doc[field_name]
    end
  end
end
