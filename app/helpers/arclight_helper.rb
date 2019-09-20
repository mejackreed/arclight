# frozen_string_literal: true

##
# Generic Helpers used in Arclight
module ArclightHelper
  ##
  # @param [SolrDocument]
  def parents_to_links(document)
    breadcrumb_links = []

    breadcrumb_links << build_repository_link(document)

    breadcrumb_links << document_parents(document).map do |parent|
      link_to parent.label, solr_document_path(parent.global_id)
    end

    safe_join(breadcrumb_links, t('arclight.breadcrumb_separator'))
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
      t('arclight.breadcrumb_separator')
    )
  end

  ##
  # @param [SolrDocument]
  def component_parents_to_links(document)
    parents = document_parents(document)
    return unless parents.length > 1

    safe_join(parents.slice(1, 999).map do |parent|
      link_to parent.label, solr_document_path(parent.global_id)
    end, t('arclight.breadcrumb_separator'))
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
        t('arclight.breadcrumb_separator'),
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
    return unless try(:search_state)

    repos = facets_from_request.find { |f| f.name == 'repository_sim' }.try(:items)
    faceted = repos && repos.length == 1 && repos.first.value
    Arclight::Repository.find_by(name: repos.first.value) if faceted
  end

  def hierarchy_component_context?
    params[:hierarchy_context] == 'component'
  end

  # determine which icon to show in search results header
  # these icon names will need to be updated when the icons are determined
  def document_header_icon(document)
    case document.level&.downcase
    when 'collection'
      'collection'
    when 'file'
      'file'
    else
      'container'
    end
  end

  def render_grouped_documents(documents)
    safe_join(
      documents.each_with_index.map do |document, i|
        render_document_partial(document, :arclight_index_group_document, document_counter: i)
      end,
      raw('<hr>')
    )
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

  def nested_lists(document)
    document.parent_ids.reverse.each.with_index.reduce(''.html_safe) do |acc, (parent_id, i)|
      content_tag(:ul) do
        content_tag(:li, id: parent_id) do
          safe_join(
            [
              list_go_getter(document, parent_id, i),
              acc
            ]
          )
        end
      end
    end
  end

  def list_go_getter(document, parent_id, index)
    reverse_index = document.parent_ids.length - index - 1
    content_tag(
      :div, '',
      class: "context-navigator al-hierarchy-level-#{document.component_level} extra-indent documents-hierarchy",
      data: {
        arclight: {
          hierarchy: true,
          level: document.parent_ids.index(parent_id) + 1,
          path: search_catalog_path(hierarchy_context: 'component'),
          name: document.collection_name,
          parent: parent_id,
          originalDocument: document.id,
          originalParents: document.parent_ids
        }
      }
    )
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
