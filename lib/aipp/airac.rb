module AIPP

  ##
  # Calculate the AIRAC date and AIRAC ID for the given +any_date+
  class AIRAC
    ##
    # First AIRAC date following the last cycle length modification
    ROOT_DATE = Date.parse('2015-06-25').freeze

    ##
    # Length of one AIRAC cycle
    DAYS_PER_CYCLE = 28

    attr_reader :date, :id

    def initialize(any_date = nil)
      any_date ||= Date.today
      fail(ArgumentError, "argument must be of class Date") unless any_date.is_a? Date
      fail(ArgumentError, "cannot calculate dates before #{ROOT_DATE}") if any_date < ROOT_DATE
      @date = date_for(any_date)
      @id = id_for(@date)
    end

    def next_date
      date + DAYS_PER_CYCLE
    end

    def next_id
      id_for next_date
    end

    private

    ##
    # Find the AIRAC date for +any_date+
    def date_for(any_date)
      ROOT_DATE + (any_date - ROOT_DATE).to_i / DAYS_PER_CYCLE * DAYS_PER_CYCLE
    end

    ##
    # Find the AIRAC ID for the AIRAC +date+
    def id_for(date)
      (date.year % 100) * 100 + ((date.yday - 1) / 28) + 1
    end

  end
end
