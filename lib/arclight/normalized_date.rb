# frozen_string_literal: true

module Arclight
  ##
  # A utility class to normalize dates, typically by joining inclusive and bulk dates
  # e.g., "1990-2000, bulk 1990-1999"
  # @see http://www2.archivists.org/standards/DACS/part_I/chapter_2/4_date
  class NormalizedDate
    # @param [String | Array<String>] `inclusive` from the `unitdate`
    # @param [String] `bulk` from the `unitdate`
    # @param [String] `other` from the `unitdate` when type is not specified
    def initialize(inclusiveHash, bulkHash = nil, otherHash = nil)
      @inclusive = []
      @bulk = []
      @other = []
      inclusiveHash.each do |inclusive|
        if inclusive.is_a? Array # of YYYY-YYYY for ranges
          @inclusive << YearRange.new(inclusive.include?('/') ? inclusive : inclusive.map { |v| v.tr('-', '/') }).to_s
        elsif inclusive.present?
          @inclusive << inclusive.strip
        end
      end
      bulkHash.each do |bulk|
        @bulk << bulk.strip if bulk.present?
      end
      otherHash.each do |other|
        @other << other.strip if other.present?
      end
      @inclusive = @inclusive.join(", ")
      @bulk = @bulk.join(", ")
      @other = @other.join(", ")
    end

    # @return [String] the normalized title/date
    def to_s
      normalize
    end

    private

    attr_reader :inclusive, :bulk, :other

    # @see http://www2.archivists.org/standards/DACS/part_I/chapter_2/4_date for rules
    def normalize
      if inclusive.present?
        result = inclusive.to_s
        result << ", bulk #{bulk}" if bulk.present?
      elsif other.present?
        result = other.to_s
      else
        result = nil
      end
      return if result.blank?
      result.strip
    end
  end
end
