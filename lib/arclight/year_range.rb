# frozen_string_literal: true

module Arclight
  # A range of years that handles gaps, such as [1999, 2000, 2002].
  # Primary usage is:
  # ```
  # range = YearRange.new('1999/2004')
  # range.years => [1999, 2000, 2001, 2002, 2003, 2004]
  # range.to_s => '1999-2004'
  # range << range.parse_ranges(['2010/2010'])
  # range.years => [1999, 2000, 2001, 2002, 2003, 2004, 2010]
  # range.to_s => '1999-2004, 2010'
  # ```
  class YearRange
    attr_accessor :years

    # @param [Array<String>] `dates` in the form YYYY/YYYY
    def initialize(dates = nil)
      @years = []
      self << parse_ranges(dates) if dates.present?
      self
    end

    # @return [String] a concise, human-readable version of the year range, including gaps
    def to_s
      return if years.empty?
      return to_s_for_streak(years) unless gaps?

      to_s_with_gaps
    end

    # @param [Array<Integer>] `other` the set of years to add
    def <<(other)
      return self if other.blank?

      @years |= other # will remove duplicates
      @years.sort!
      self
    end

    # @param [String] `dates` in the form YYYY/YYYY
    # @return [Array<Integer>] the set of years in the given range
    def parse_range(dates)
      return if dates.blank?

      start_year, end_year = dates.split('/').map { |date| to_year_from_iso8601(date) }
      return [start_year] if end_year.blank?
      raise ArgumentError, "Range is too large: #{dates}" if (end_year - start_year) > 3000
      raise ArgumentError, "Range is inverted: #{dates}" unless start_year <= end_year

      (start_year..end_year).to_a
    end

    # @param [Array<String>] `dates` in the form YYYY/YYYY
    # @return [Array<Integer>] the set of years in the given range
    def parse_ranges(dates)
      dates.map { |date| parse_range(date) }.flatten.sort.uniq
    end

    # @param [String] `date` a date in one of these formats:
    #                        YYYY, YYYY-MM, YYYY-MM-DD, and YYYYMMDD
    def to_year_from_iso8601(date)
      return if date.blank?

      date.split('-').first[0..3].to_i # Time.parse doesn't work here
    end

    # @return [Boolean] are there gaps between the years, such as 1999, 2000, 2002?
    def gaps?
      return false if years.blank?

      (years.min..years.max).to_a != years
    end

    private

    # Deals with making a human-readable range for years with 1 or more gaps.
    # It involves detection of streaks between the gaps.
    # @return [String] 1999-2000, 2002 for 1999, 2000, 2002
    def to_s_with_gaps # rubocop: disable Metrics/AbcSize, Metrics/MethodLength
      raise ArgumentError if years.blank? || years.length < 2

      results = []
      streak = [years[0]]
      i = streak.first
      years[1..-1].each do |j|
        i += 1
        if i == j
          streak << j
        else # we have a gap
          results << if streak.length == 1
                       streak.first.to_s
                     else
                       to_s_for_streak(streak)
                     end
          streak = [j]
          i = j
        end
      end
      results << to_s_for_streak(streak)
      results.join(', ')
    end

    def to_s_for_streak(streak)
      return streak.min.to_s if streak.min == streak.max

      streak.minmax.map(&:to_s).join('-')
    end
  end
end
