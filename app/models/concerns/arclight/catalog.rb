# frozen_string_literal: true

module Arclight
  ##
  # Arclight specific methods for the Catalog
  module Catalog
    extend ActiveSupport::Concern

    included do
      before_action only: :index do
        if (params.dig(:f, :collection_sim) || []).any?(&:blank?)
          params[:f][:collection_sim].delete_if(&:blank?)
          params[:f].delete(:collection_sim) if params[:f][:collection_sim].blank?
        end
      end
    end

    ##
    # Overriding the Blacklight method so that the hierarchy view does not start
    # a new search session
    def start_new_search_session?
      !%w[hierarchy online_contents collection_context].include?(params[:view]) && super
    end

    ##
    # Overriding the Blacklight method so that hierarchy does not get stored as
    # the preferred view
    def store_preferred_view
      return if %w[hierarchy online_contents collection_context].include?(params[:view])

      super
    end
  end
end
