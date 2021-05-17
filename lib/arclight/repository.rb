# frozen_string_literal: true

module Arclight
  #
  # Static information about a given repository identified by a unique `slug`
  #
  class Repository
    include ActiveModel::Conversion # for to_partial_path

    attr_accessor :slug, :collection_count

    # @param [String] `slug` the unique identifier for the repository
    # @param [Hash] `data`
    def initialize(slug, data = {})
      @slug = slug
      data.each do |field, value|
        self.class.attr_accessor field.to_sym
        send("#{field}=", value) if value.present?
      end
    end

    # @return [String] handles the formatting of "city, state zip, country"
    def city_state_zip_country
      state_zip = state
      state_zip += " #{zip}" if zip
      [city, state_zip, country].compact.join(', ')
    end

    # Why are we using self#respond_to? below?
    #
    # All the keys in the config hash from `repositories.yml` are
    # on-the-fly added as attr_accessors up in #initialize. If the
    # request_types key isn't present, the method won't be created.
    #
    # Since the original data is thrown away, this is the best way
    # to see if that key was present.
    def request_config_present?
      return false unless respond_to? :request_types
      return false if request_types.nil? || request_types.empty?

      request_configs = request_types.map { |_k, v| v }
      request_configs[0]&.fetch('request_url').present? &&
        request_configs[0]&.fetch('request_mappings').present?
    end

    def request_config_present_for_type?(type)
      return false unless type && request_config_present?

      config = request_types[type]
      config&.fetch('request_url').present? &&
        config&.fetch('request_mappings').present?
    end

    def request_config_for_type(type)
      return nil unless type && request_config_present_for_type?(type)

      request_types[type]
    end

    def request_url_for_type(type)
      return nil unless type && request_config_present_for_type?(type)

      config = request_config_for_type(type)
      config.fetch('request_url')
    end

    def request_mappings_for_type(type)
      return nil unless type && request_config_present_for_type?(type)

      config = request_config_for_type(type)
      config.fetch('request_mappings')
    end

    def available_request_types
      return [] unless request_types.present?

      request_types.keys
    end

    # Load repository information from a YAML file
    #
    # @param [String] `filename`
    # @return [Hash<Slug,Repository>]
    def self.from_yaml(file)
      repos = {}
      data = YAML.safe_load(File.read(file))
      data.keys.each do |slug|
        repos[slug] = new(slug, data[slug])
      end
      repos
    end

    # Mimics ActiveRecord's `all` behavior
    #
    # @return [Array<Repository>]
    def self.all(yaml_file = nil)
      yaml_file = ENV['REPOSITORY_FILE'] || 'config/repositories.yml' if yaml_file.nil?
      from_yaml(yaml_file).values
    end

    # Mimics ActiveRecord dynamic `find_by` behavior for the slug or name
    #
    # @param [String] `slug` or `name`
    # @return [Repository]
    def self.find_by(slug: nil, name: nil, yaml_file: nil)
      if slug
        all(yaml_file).find { |repo| repo.slug == slug }
      elsif name
        all(yaml_file).find { |repo| repo.name == name }
      else
        raise ArgumentError, 'Requires either slug or name parameters to find_by'
      end
    end

    # Mimics ActiveRecord dynamic `find_by!` behavior for the slug or name
    #
    # @param [String] `slug` or `name` -- same as `find_by`
    # @return [Repository]
    # @raise [ActiveRecord::RecordNotFound] if cannot find repository
    def self.find_by!(**kwargs)
      repository = find_by(**kwargs)
      raise ActiveRecord::RecordNotFound if repository.blank?

      repository
    end
  end
end
