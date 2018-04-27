module AIPP

  # AIRAC cycle date calculations
  #
  # @example
  #   airac = AIPP::AIRAC.new('2018-01-01')
  #   airac.date        # => #<Date: 2017-12-07 ((2458095j,0s,0n),+0s,2299161j)>
  #   airac.id          # => 1713
  #   airac.next_date   # => #<Date: 2018-01-04 ((2458123j,0s,0n),+0s,2299161j)>
  #   airac.next_id     # => 1801
  class AIRAC
    # First AIRAC date following the last cycle length modification
    ROOT_DATE = Date.parse('2015-06-25').freeze

    # Length of one AIRAC cycle
    DAYS_PER_CYCLE = 28

    # @return [Date] AIRAC effective on date
    attr_reader :date

    # @return [Integer] AIRAC cycle ID
    attr_reader :id

    # @param any_date [Date] any date within the AIRAC cycle (default: today)
    def initialize(any_date = nil)
      any_date = any_date ? Date.parse(any_date.to_s) : Date.today
      fail(ArgumentError, "cannot calculate dates before #{ROOT_DATE}") if any_date < ROOT_DATE
      @date = date_for(any_date)
      @id = id_for(@date)
    end

    # @return [Date] next AIRAC effective on date
    def next_date
      date + DAYS_PER_CYCLE
    end

    # @return [Integer] next AIRAC cycle ID
    def next_id
      id_for next_date
    end

    private

    # Find the AIRAC date for +any_date+
    def date_for(any_date)
      ROOT_DATE + (any_date - ROOT_DATE).to_i / DAYS_PER_CYCLE * DAYS_PER_CYCLE
    end

    # Find the AIRAC ID for the AIRAC +date+
    def id_for(date)
      (date.year % 100) * 100 + ((date.yday - 1) / 28) + 1
    end

  end
end
