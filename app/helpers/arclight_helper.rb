# frozen_string_literal: true

##
# Generic Helpers used in Arclight
module ArclightHelper
  def aria_hidden_breadcrumb_separator
    safe_join(
      [
        '<span aria-hidden="true">'.html_safe,
        t('arclight.breadcrumb_separator'),
        '</span>'.html_safe
      ]
    )
  end

  ##
  # @param [SolrDocument]
  def parents_to_links(document)
    breadcrumb_links = []

    breadcrumb_links << build_repository_link(document)

    breadcrumb_links << document_parents(document).map do |parent|
      link_to parent.label, solr_document_path(parent.global_id)
    end

    safe_join(breadcrumb_links, aria_hidden_breadcrumb_separator)
  end

  ##
  # For a non-grouped compact view, display the breadcrumbs with the following
  # algorithm:
  #  - Display only the first two parts of the item breadcrumb: the repository
  #    and the collection.
  #  - After the collection and the breadcrumb divider icon, show an ellipses as
  #    shown in the mockup above. The repository and the collection parts are
  #    linked as usual; the ellipses is not linked.
  def regular_compact_breadcrumbs(document)
    breadcrumb_links = [build_repository_link(document)]

    parents = document_parents(document)
    breadcrumb_links << parents[0, 1].map do |parent|
      link_to parent.label, solr_document_path(parent.global_id)
    end

    breadcrumb_links << '&hellip;'.html_safe if parents.length > 1

    safe_join(
      breadcrumb_links,
      aria_hidden_breadcrumb_separator
    )
  end

  ##
  # @param [SolrDocument]
  def component_parents_to_links(document)
    parents = document_parents(document)
    return unless parents.length > 1

    safe_join(parents.slice(1, 999).map do |parent|
      link_to parent.label, solr_document_path(parent.global_id)
    end, aria_hidden_breadcrumb_separator)
  end

  ##
  # @param [SolrDocument]
  def component_top_level_parent_to_links(document)
    parents = document_parents(document)
    return unless parents.length > 1

    parent_link = link_to(parents[1].label, solr_document_path(parents[1].global_id))
    return parent_link if parents.length == 2

    safe_join(
      [
        parent_link,
        aria_hidden_breadcrumb_separator,
        '&hellip;'.html_safe
      ]
    )
  end

  ##
  # @param [SolrDocument]
  def document_parents(document)
    Arclight::Parents.from_solr_document(document).as_parents
  end

  def repository_collections_path(repository)
    search_action_url(
      f: {
        repository_sim: [repository.name],
        level_sim: ['Collection']
      }
    )
  end

  # Returns the i18n-ed string to be used as the h1 in search results
  def search_results_header_text
    if (repo = repository_faceted_on).present?
      t('arclight.search.repository_header', repository: repo.name)
    elsif collection_active?
      t('arclight.search.collections_header')
    else
      t('blacklight.search.header')
    end
  end

  ##
  # Classes used for customized show page in arclight
  def custom_show_content_classes
    'col-md-12 show-document'
  end

  def normalize_id(id)
    Arclight::NormalizedId.new(id).to_s
  end

  def collection_active?
    try(:search_state) && search_state.params_for_search.try(:[], 'f').try(:[], 'level_sim') == ['Collection']
  end

  def collection_active_class
    'active' if collection_active?
  end

  def collection_count
    @response.response['numFound']
  end

  def grouped?
    try(:search_state) && search_state.params_for_search.try(:[], 'group') == 'true'
  end

  def search_with_group
    search_state.params_for_search.merge('group' => 'true').except('page')
  end

  def search_without_group
    search_state.params_for_search.except('group', 'page')
  end

  def search_within_collection(collection_name, search)
    search.merge(f: { collection_sim: [collection_name] })
  end

  def on_repositories_show?
    controller_name == 'repositories' && action_name == 'show'
  end

  def on_repositories_index?
    controller_name == 'repositories' && action_name == 'index'
  end

  # the Repositories menu item is only active on the Repositories index page
  def repositories_active_class
    'active' if on_repositories_index?
  end

  def fields_have_content?(document, field_accessor)
    generic_document_fields(field_accessor).any? do |_, field|
      generic_should_render_field?(field_accessor, document, field)
    end
  end

  # If we have a facet on the repository, then return the Repository object for it
  #
  # @return [Repository]
  def repository_faceted_on
    return unless try(:search_state) && facet_field_in_params?('repository_sim')

    repos = Array(facet_params('repository_sim'))
    faceted = repos && repos.length == 1 && repos.first
    Arclight::Repository.find_by(name: repos.first) if faceted
  end

  def hierarchy_component_context?
    params[:hierarchy_context] == 'component'
  end

  # determine which icon to show in search results header
  # these icon names will need to be updated when the icons are determined
  def document_or_parent_icon(document)
    case document.level&.downcase
    when 'collection'
      'collection'
    when 'file'
      'file'
    when 'series', 'subseries'
      'folder'
    else
      'container'
    end
  end

  def render_grouped_documents(documents)
    safe_join(
      documents.each_with_index.map do |document, i|
        render_document_partial(document, :arclight_index_group_document, document_counter: i)
      end
    )
  end

  def ead_files(document)
    files = Arclight::DocumentDownloads.new(document, document.collection_unitid).files
    files.find do |file|
      file.type == 'ead'
    end
  end

  ##
  # Defines custom helpers used for creating unique metadata blocks to render
  Arclight::Engine.config.catalog_controller_field_accessors.each do |config_field|
    ##
    # Mimics what document_show_fields from Blacklight does
    # https://github.com/projectblacklight/blacklight/blob/dee8d794125306ec8d4ab834a6a45bcf9671c791/app/helpers/blacklight/configuration_helper_behavior.rb#L35-L38
    define_method(:"document_#{config_field}s") do |_document = nil|
      blacklight_config.send(:"#{config_field}s")
    end

    ##
    # Mimics what render_document_show_field_label from Blacklight does
    # https://github.com/projectblacklight/blacklight/blob/dee8d794125306ec8d4ab834a6a45bcf9671c791/app/helpers/blacklight/blacklight_helper_behavior.rb#L136-L156
    define_method(:"render_document_#{config_field}_label") do |*args|
      options = args.extract_options!
      document = args.first

      field = options[:field]

      t(:'blacklight.search.show.label', label: send(:"document_#{config_field}_label", document, field))
    end

    ##
    # Mimics what document_show_field_label from Blacklight does
    # https://github.com/projectblacklight/blacklight/blob/dee8d794125306ec8d4ab834a6a45bcf9671c791/app/helpers/blacklight/configuration_helper_behavior.rb#L67-L74
    define_method(:"document_#{config_field}_label") do |document, field|
      field_config = send(:"document_#{config_field}s", document)[field]
      field_config ||= Blacklight::Configuration::NullField.new(key: field)

      field_config.display_label('show')
    end

    ##
    # Mimics what should_render_show_field? from Blacklight does
    # https://github.com/projectblacklight/blacklight/blob/dee8d794125306ec8d4ab834a6a45bcf9671c791/app/helpers/blacklight/blacklight_helper_behavior.rb#L84-L92
    define_method(:"should_render_#{config_field}?") do |document, field_config|
      should_render_field?(field_config, document) && document_has_value?(document, field_config)
    end
  end

  ##
  # Calls the method for a configured field
  def generic_document_fields(config_field)
    send(:"document_#{config_field}s")
  end

  ##
  # Calls the method for a configured field
  def generic_should_render_field?(config_field, document, field)
    send(:"should_render_#{config_field}?", document, field)
  end

  ##
  # Calls the method for a configured field
  def generic_render_document_field_label(config_field, document, field: field_name)
    send(:"render_document_#{config_field}_label", document, field: field)
  end

  def fetch_siblings(document)
    siblings = Blacklight
               .default_index
               .connection
               .get('select',
                    params: {
                      fq: ["{!term f=parent_ssi}#{document.parent_ids[-1]}",
                           "{!term f=component_level_isim}#{document.component_level}"],
                      facet: false,
                      rows: 999_999_999
                    })
    solr_docs = siblings['response']['docs'].collect { |d| SolrDocument.new d }
    solr_docs
  end

  def fetch_sorted_siblings(document)
    siblings = fetch_siblings(document)
    original_index = siblings.find_index { |d| d.id == document.id } || -1
    before_siblings = siblings.slice(0, original_index) || []
    after_siblings = siblings.slice(original_index + 1, siblings.length) || []
    [before_siblings, after_siblings]
  end

  def render_document_context(document, core: nil, is_original: false)
    parents = document.parent_ids
    before_siblings, after_siblings = fetch_sorted_siblings(document)
    new_core = render 'catalog/nested_component_context',
                      document: document,
                      core: core,
                      document_counter: parents.length,
                      is_original: is_original,
                      before_siblings: before_siblings.to_set,
                      after_siblings: after_siblings.to_set
    if parents.length > 1
      parent_search_id = parents[0] + parents[-1]
      parent = SolrDocument.find(parent_search_id)
      return render_document_context(parent, core: new_core)
    end
    new_core
  end

  ##
  # Determine if the user is currently under a collection context
  # This is any record view (because it is either the collection or a component w/i a collection)
  # or in a result view where a collection facet has been selected
  def within_collection_context?
    return true if record_view?

    results_view? && params.dig(:f, 'collection_sim')
  end

  def results_view?
    controller_name == 'catalog' && action_name == 'index'
  end

  def record_view?
    controller_name == 'catalog' && action_name == 'show'
  end

  private

  def build_repository_link(document)
    repository_path = document.repository_config&.slug
    if repository_path.present?
      link_to(document.repository, arclight_engine.repository_path(repository_path))
    else
      content_tag(:span, document.repository)
    end
  end
end
