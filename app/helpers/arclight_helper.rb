# frozen_string_literal: true

##
# Generic Helpers used in Arclight
module ArclightHelper
  ##
  # @param [SolrDocument]
  def parents_to_links(document)
    safe_join(Arclight::Parents.from_solr_document(document).as_parents.map do |parent|
      link_to parent.label, solr_document_path(parent.global_id)
    end, t('arclight.breadcrumb_separator'))
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
    search_catalog_path search_state.params_for_search.merge('group' => 'true')
  end

  def search_without_group
    search_catalog_path(search_state.params_for_search.reject { |k| k == 'group' })
  end

  ##
  # Looks for `document.unitid` in the downloads configuration
  # @param [SolrDocument] `document`
  # @param [Hash] `config` metadata for downloadable files
  # @return [Hash] with `:href` and `:size` keys
  def collection_downloads(document, config = load_download_config)
    config = config[document.unitid] if config.present?
    return {} if config.blank?
    parse_collection_downloads(config)
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

  # @return [Hash] loaded from config/downloads.yml, or `{}` if missing file
  def load_download_config(filename = Rails.root.join('config', 'downloads.yml'))
    YAML.safe_load(File.read(filename))
  rescue Errno::ENOENT
    {}
  end

  # @return [Hash] the downloads for the given configuration using Hash symbols
  # @example `{ pdf: { href: 'http://...', size: '123 KB' } }`
  def parse_collection_downloads(config, results = {})
    %w[pdf ead].each do |type|
      next if config[type].blank?
      results[type.to_sym] = {
        href: config[type]['href'],
        size: display_size(config[type]['size'])
      }
    end
    results
  end

  # Show a human readable size, or if it's already a string, show that
  # @return [String] human readable siz
  def display_size(size)
    size = number_to_human_size(size.to_i + 1) if size.is_a?(Numeric) || size =~ /^[0-9]+$/ # assumes bytes
    size.to_s
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
end
