# frozen_string_literal: true

module Arclight
  module Traject
    # Provides a Traject Reader for XML Documents which removes the namespaces
    class NokogiriNamespacelessReader < ::Traject::NokogiriReader
      # Overrides the #each method (which is used for iterating through each Document)
      # @param args
      # @see ::Traject::NokogiriReader#each
      # @see Enumerable#each
      def each(*args)
        return to_enum(:each, *args) unless block_given?

        super do |doc|
          new_doc = doc.dup
          new_doc.remove_namespaces!
          yield new_doc
        end
      end
    end
  end
end
