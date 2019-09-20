# frozen_string_literal: true

class CatalogController < ApplicationController
  include Blacklight::Catalog
  include Arclight::Catalog
  include Arclight::FieldConfigHelpers

  configure_blacklight do |config|
    ## Class for sending and receiving requests from a search index
    # config.repository_class = Blacklight::Solr::Repository
    #
    ## Class for converting Blacklight's url parameters to into request parameters for the search index
    # config.search_builder_class = ::SearchBuilder
    #
    ## Model that maps search index responses to the blacklight response model
    # config.response_model = Blacklight::Solr::Response

    ## Default parameters to send to solr for all search-like requests. See also SearchBuilder#processed_parameters
    config.default_solr_params = {
      rows: 10
    }

    # solr path which will be added to solr base url before the other solr params.
    # config.solr_path = 'select'

    # items to show per page, each number in the array represent another option to choose from.
    # config.per_page = [10,20,50,100]

    ## Default parameters to send on single-document requests to Solr. These settings are the Blacklight defaults (see SearchHelper#solr_doc_params) or
    ## parameters included in the Blacklight-jetty document requestHandler.
    #
    # config.default_document_solr_params = {
    #  qt: 'document',
    #  ## These are hard-coded in the blacklight 'document' requestHandler
    #  # fl: '*',
    #  # rows: 1,
    #  # q: '{!term f=id v=$id}'
    # }

    # solr field configuration for search results/index views
    config.index.title_field = 'normalized_title_ssm'
    config.index.display_type_field = 'level_ssm'
    # config.index.thumbnail_field = 'thumbnail_path_ss'

    # solr field configuration for document/show views
    # config.show.title_field = 'title_display'
    config.show.display_type_field = 'level_ssm'
    # config.show.thumbnail_field = 'thumbnail_path_ss'

    config.add_results_document_tool(:bookmark, partial: 'bookmark_control', if: :render_bookmarks_control?)

    config.add_results_collection_tool(:sort_widget)
    config.add_results_collection_tool(:per_page_widget)
    config.add_results_collection_tool(:view_type_group)

    config.add_show_tools_partial(:bookmark, partial: 'bookmark_control', if: :render_bookmarks_control?)
    config.add_show_tools_partial(:email, callback: :email_action, validator: :validate_email_params)
    config.add_show_tools_partial(:sms, if: :render_sms_action?, callback: :sms_action, validator: :validate_sms_params)
    config.add_show_tools_partial(:citation)

    config.add_nav_action(:bookmark, partial: 'blacklight/nav/bookmark', if: :render_bookmarks_control?)
    config.add_nav_action(:search_history, partial: 'blacklight/nav/search_history')

    # solr fields that will be treated as facets by the blacklight application
    #   The ordering of the field names is the order of the display
    #
    # Setting a limit will trigger Blacklight's 'more' facet values link.
    # * If left unset, then all facet values returned by solr will be displayed.
    # * If set to an integer, then "f.somefield.facet.limit" will be added to
    # solr request, with actual solr request being +1 your configured limit --
    # you configure the number of items you actually want _displayed_ in a page.
    # * If set to 'true', then no additional parameters will be sent to solr,
    # but any 'sniffed' request limit parameters will be used for paging, with
    # paging at requested limit -1. Can sniff from facet.limit or
    # f.specific_field.facet.limit solr request params. This 'true' config
    # can be used if you set limits in :default_solr_params, or as defaults
    # on the solr side in the request handler itself. Request handler defaults
    # sniffing requires solr requests to be made with "echoParams=all", for
    # app code to actually have it echo'd back to see it.
    #
    # :show may be set to false if you don't want the facet to be drawn in the
    # facet bar
    #
    # set :index_range to true if you want the facet pagination view to have facet prefix-based navigation
    #  (useful when user clicks "more" on a large facet and wants to navigate alphabetically across a large set of results)
    # :index_range can be an array or range of prefixes that will be used to create the navigation (note: It is case sensitive when searching values)

    config.add_facet_field 'collection_sim', label: 'Collection', limit: 10
    config.add_facet_field 'creator_ssim', label: 'Creator', limit: 10
    config.add_facet_field 'creators_ssim', label: 'Creator', show: false
    config.add_facet_field 'date_range_sim', label: 'Date range', range: true
    config.add_facet_field 'level_sim', label: 'Level', limit: 10
    config.add_facet_field 'names_ssim', label: 'Names', limit: 10
    config.add_facet_field 'repository_sim', label: 'Repository', limit: 10
    config.add_facet_field 'geogname_sim', label: 'Place', limit: 10
    config.add_facet_field 'places_ssim', label: 'Places', show: false
    config.add_facet_field 'access_subjects_ssim', label: 'Subject', limit: 10

    # Have BL send all facet field names to Solr, which has been the default
    # previously. Simply remove these lines if you'd rather use Solr request
    # handler defaults, or have no facets.
    config.add_facet_fields_to_solr_request!

    # solr fields to be displayed in the index (search results) view
    #   The ordering of the field names is the order of the display
    config.add_index_field 'unitid_ssm', label: 'Unit ID'
    config.add_index_field 'repository_ssm', label: 'Repository'
    config.add_index_field 'normalized_date_ssm', label: 'Date'
    config.add_index_field 'creator_ssm', label: 'Creator'
    config.add_index_field 'language_ssm', label: 'Language'
    config.add_index_field 'scopecontent_ssm', label: 'Scope Content'
    config.add_index_field 'extent_ssm', label: 'Physical Description'
    config.add_index_field 'accessrestrict_ssm', label: 'Conditions Governing Access'
    config.add_index_field 'collection_ssm', label: 'Collection Title'
    config.add_index_field 'geogname_ssm', label: 'Place'

    config.add_facet_field 'has_online_content_ssim', label: 'Access', query: {
      online: { label: 'Online access', fq: 'has_online_content_ssim:true' }
    }

    # solr fields to be displayed in the show (single result) view
    #   The ordering of the field names is the order of the display

    # "fielded" search configuration. Used by pulldown among other places.
    # For supported keys in hash, see rdoc for Blacklight::SearchFields
    #
    # Search fields will inherit the :qt solr request handler from
    # config[:default_solr_parameters], OR can specify a different one
    # with a :qt key/value. Below examples inherit, except for subject
    # that specifies the same :qt as default for our own internal
    # testing purposes.
    #
    # The :key is what will be used to identify this BL search field internally,
    # as well as in URLs -- so changing it after deployment may break bookmarked
    # urls.  A display label will be automatically calculated from the :key,
    # or can be specified manually to be different.

    # This one uses all the defaults set by the solr request handler. Which
    # solr request handler? The one set in config[:default_solr_parameters][:qt],
    # since we aren't specifying it otherwise.
    config.add_search_field 'all_fields', label: 'All Fields' do |field|
      field.include_in_simple_select = true
    end

    config.add_search_field 'within_collection' do |field|
      field.include_in_simple_select = false
      field.solr_parameters = {
        fq: '-level_sim:Collection'
      }
    end

    # Field-based searches. We have registered handlers in the Solr configuration
    # so we have Blacklight use the `qt` parameter to invoke them
    config.add_search_field 'keyword', label: 'Keyword' do |field|
      field.qt = 'search' # default
    end
    config.add_search_field 'name', label: 'Name' do |field|
      field.qt = 'name_search'
    end
    config.add_search_field 'place', label: 'Place' do |field|
      field.qt = 'place_search'
    end
    config.add_search_field 'subject', label: 'Subject' do |field|
      field.qt = 'subject_search'
    end
    config.add_search_field 'title', label: 'Title' do |field|
      field.qt = 'title_search'
    end

    # "sort results by" select (pulldown)
    # label in pulldown is followed by the name of the SOLR field to sort by and
    # whether the sort is ascending or descending (it must be asc or desc
    # except in the relevancy case).
    config.add_sort_field 'score desc, title_sort asc', label: 'relevance'
    config.add_sort_field 'date_sort asc', label: 'date (ascending)'
    config.add_sort_field 'date_sort desc', label: 'date (descending)'
    config.add_sort_field 'creator_sort asc', label: 'creator (A-Z)'
    config.add_sort_field 'creator_sort desc', label: 'creator (Z-A)'
    config.add_sort_field 'title_sort asc', label: 'title (A-Z)'
    config.add_sort_field 'title_sort desc', label: 'title (Z-A)'

    # If there are more than this many search results, no spelling ("did you
    # mean") suggestion is offered.
    config.spell_max = 5

    # Configuration for autocomplete suggestor
    config.autocomplete_enabled = true
    config.autocomplete_path = 'suggest'

    ##
    # Arclight Configurations

    config.show.document_presenter_class = Arclight::ShowPresenter
    config.index.document_presenter_class = Arclight::IndexPresenter

    ##
    # Configuration for partials
    config.index.partials = %i[arclight_index_default]

    ##
    # Configuration for index actions
    config.index.document_actions << :containers
    config.index.document_actions << :online_content_label
    config.add_results_document_tool :arclight_bookmark_control, partial: 'arclight_bookmark_control'
    config.index.document_actions.delete(:bookmark)

    config.show.metadata_partials = %i[
      summary_field
      access_field
      background_field
      related_field
      indexed_terms_field
    ]

    config.show.context_access_tab_items = %i[
      terms_field
      cite_field
      in_person_field
      contact_field
    ]

    config.show.component_metadata_partials = %i[
      component_field
      component_indexed_terms_field
    ]

    config.show.component_access_tab_items = %i[
      component_terms_field
      cite_field
      in_person_field
      contact_field
    ]


    # ===========================
    # COLLECTION SHOW PAGE FIELDS
    # ===========================

    # Collection Show Page - Summary Section
    config.add_summary_field 'creators_ssim', label: 'Creator', link_to_facet: true
    config.add_summary_field 'abstract_ssm', label: 'Abstract', helper_method: :paragraph_separator
    config.add_summary_field 'extent_ssm', label: 'Extent'
    config.add_summary_field 'language_ssm', label: 'Language'
    config.add_summary_field 'prefercite_ssm', label: 'Preferred citation'

    # Collection Show Page - Access Section
    config.add_access_field 'accessrestrict_ssm', label: 'Conditions Governing Access', helper_method: :paragraph_separator
    config.add_access_field 'userestrict_ssm', label: 'Terms Of Use', helper_method: :paragraph_separator

    # Collection Show Page - Background Section
    config.add_background_field 'scopecontent_ssm', label: 'Scope and Content', helper_method: :paragraph_separator
    config.add_background_field 'bioghist_ssm', label: 'Biographical / Historical', helper_method: :paragraph_separator
    config.add_background_field 'acqinfo_ssm', label: 'Acquisition information', helper_method: :paragraph_separator
    config.add_background_field 'appraisal_ssm', label: 'Appraisal information', helper_method: :paragraph_separator
    config.add_background_field 'custodhist_ssm', label: 'Custodial history', helper_method: :paragraph_separator
    config.add_background_field 'processinfo_ssm', label: 'Processing information', helper_method: :paragraph_separator
    config.add_background_field 'arrangement_ssm', label: 'Arrangement', helper_method: :paragraph_separator
    config.add_background_field 'accruals_ssm', label: 'Accruals', helper_method: :paragraph_separator
    config.add_background_field 'phystech_ssm', label: 'Physical / technical requirements', helper_method: :paragraph_separator
    config.add_background_field 'physloc_ssm', label: 'Physical location', helper_method: :paragraph_separator
    config.add_background_field 'descrules_ssm', label: 'Rules or conventions', helper_method: :paragraph_separator


    # Collection Show Page - Related Section
    config.add_related_field 'relatedmaterial_ssm', label: 'Related material', helper_method: :paragraph_separator
    config.add_related_field 'separatedmaterial_ssm', label: 'Separated material', helper_method: :paragraph_separator
    config.add_related_field 'otherfindaid_ssm', label: 'Other finding aids', helper_method: :paragraph_separator
    config.add_related_field 'altformavail_ssm', label: 'Alternative form available', helper_method: :paragraph_separator
    config.add_related_field 'originalsloc_ssm', label: 'Location of originals', helper_method: :paragraph_separator

    # Collection Show Page - Indexed Terms Section
    config.add_indexed_terms_field 'access_subjects_ssim', label: 'Subjects', link_to_facet: true, separator_options: {
      words_connector: '<br/>',
      two_words_connector: '<br/>',
      last_word_connector: '<br/>'
    }

    config.add_indexed_terms_field 'names_coll_ssim', label: 'Names', separator_options: {
      words_connector: '<br/>',
      two_words_connector: '<br/>',
      last_word_connector: '<br/>'
    }, helper_method: :link_to_name_facet

    config.add_indexed_terms_field 'places_ssim', label: 'Places', link_to_facet: true, separator_options: {
      words_connector: '<br/>',
      two_words_connector: '<br/>',
      last_word_connector: '<br/>'
    }


    # ==========================
    # COMPONENT SHOW PAGE FIELDS
    # ==========================

    # Component Show Page - Metadata Section
    config.add_component_field 'containers', label: 'Containers', accessor: 'containers', separator_options: {
      words_connector: ', ',
      two_words_connector: ', ',
      last_word_connector: ', '
    }, if: lambda { |_context, _field_config, document|
      document.containers.present?
    }
    config.add_component_field 'abstract_ssm', label: 'Abstract', helper_method: :paragraph_separator
    config.add_component_field 'extent_ssm', label: 'Extent'
    config.add_component_field 'scopecontent_ssm', label: 'Scope and Content', helper_method: :paragraph_separator
    config.add_component_field 'accessrestrict_ssm', label: 'Restrictions', helper_method: :paragraph_separator
    config.add_component_field 'userestrict_ssm', label: 'Terms of Access', helper_method: :paragraph_separator
    config.add_component_field 'parent_access_restrict_ssm', label: 'Parent Restrictions', helper_method: :paragraph_separator
    config.add_component_field 'parent_access_terms_ssm', label: 'Terms of Access', helper_method: :paragraph_separator
    config.add_component_field 'acqinfo_ssm', label: 'Acquisition information', helper_method: :paragraph_separator
    config.add_component_field 'appraisal_ssm', label: 'Appraisal information', helper_method: :paragraph_separator
    config.add_component_field 'custodhist_ssm', label: 'Custodial history', helper_method: :paragraph_separator
    config.add_component_field 'processinfo_ssm', label: 'Processing information', helper_method: :paragraph_separator
    config.add_component_field 'arrangement_ssm', label: 'Arrangement', helper_method: :paragraph_separator
    config.add_component_field 'accruals_ssm', label: 'Accruals', helper_method: :paragraph_separator
    config.add_component_field 'phystech_ssm', label: 'Physical / technical requirements', helper_method: :paragraph_separator
    config.add_component_field 'physloc_ssm', label: 'Physical location', helper_method: :paragraph_separator

    # Component Show Page - Indexed Terms Section
    config.add_component_indexed_terms_field 'access_subjects_ssim', label: 'Subjects', link_to_facet: true, separator_options: {
      words_connector: '<br/>',
      two_words_connector: '<br/>',
      last_word_connector: '<br/>'
    }

    config.add_component_indexed_terms_field 'names_ssim', label: 'Names', separator_options: {
      words_connector: '<br/>',
      two_words_connector: '<br/>',
      last_word_connector: '<br/>'
    }, helper_method: :link_to_name_facet

    config.add_component_indexed_terms_field 'places_ssim', label: 'Places', link_to_facet: true, separator_options: {
      words_connector: '<br/>',
      two_words_connector: '<br/>',
      last_word_connector: '<br/>'
    }


    # =================
    # ACCESS TAB FIELDS
    # =================

    # Collection Show Page Access Tab - Terms and Conditions Section
    config.add_terms_field 'accessrestrict_ssm', label: 'Restrictions', helper_method: :paragraph_separator
    config.add_terms_field 'userestrict_ssm', label: 'Terms of Access', helper_method: :paragraph_separator

    # Component Show Page Access Tab - Terms and Condition Section
    config.add_component_terms_field 'accessrestrict_ssm', label: 'Restrictions', helper_method: :paragraph_separator
    config.add_component_terms_field 'parent_access_restrict_ssm', label: 'Parent Restrictions', helper_method: :paragraph_separator
    config.add_component_terms_field 'parent_access_terms_ssm', label: 'Terms of Access', helper_method: :paragraph_separator

    # Collection and Component Show Page Access Tab - In Person Section
    config.add_in_person_field 'repository_ssm', if: :repository_config_present, label: 'Location of this collection', helper_method: :context_access_tab_repository
    config.add_in_person_field 'id', if: :before_you_visit_note_present, label: 'Before you visit', helper_method: :context_access_tab_visit_note # Using ID because we know it will always exist    

    # Collection and Component Show Page Access Tab - How to Cite Section
    config.add_cite_field 'prefercite_ssm', label: 'Preferred citation'

    # Collection and Component Show Page Access Tab - Contact Section
    config.add_contact_field 'repository_ssm', if: :repository_config_present, label: 'Contact', helper_method: :access_repository_contact


    # Remove unused show document actions
    %i[citation email sms].each do |action|
      config.view_config(:show).document_actions.delete(action)
    end

    # Insert the breadcrumbs at the beginning
    config.show.partials.unshift(:show_upper_metadata)
    config.show.partials.unshift(:show_breadcrumbs)
    config.show.partials.delete(:show_header)


    ##
    # Hierarchy Index View
    config.view.hierarchy
    config.view.hierarchy.display_control = false
    config.view.hierarchy.partials = %i[index_header_hierarchy index_hierarchy]

    ##
    # Hierarchy Index View
    config.view.online_contents
    config.view.online_contents.display_control = false
    config.view.online_contents.partials = config.view.hierarchy.partials.dup

    ##
    # Collection Context
    config.view.collection_context
    config.view.collection_context.display_control = false
    config.view.collection_context.partials = %i[index_collection_context]

    ##
    # Compact index view
    config.view.compact
    config.view.compact.partials = %i[arclight_index_compact]

  end
end
