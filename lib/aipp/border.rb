module AIPP

  # Custom border geometries
  #
  # The border consists of one ore more open or closed geometries which are
  # defined by either a GeoJSON file or arrays of coordinate pairs.
  class Border

    # @return [Array<AIXM::XY>]
    attr_reader :geometries

    def initialize(geometries)
      @geometries = geometries
    end

    class << self
      undef_method :new

      # New border object from GeoJSON file
      #
      # The border GeoJSON files must be a geometry collection of one or more
      # line strings:
      #
      #   {
      #     "type": "GeometryCollection",
      #     "geometries": [
      #       {
      #         "type": "LineString",
      #         "coordinates": [
      #           [6.009531650000042, 45.12013319700009],
      #           [6.015747738000073, 45.12006702600007]
      #         ]
      #       }
      #     ]
      #   }
      #
      # Please note that GeoJSON orders coordinate tuples in mathematical order
      # as +[longitude, latitude]+!
      #
      # @param file [Pathname, String] GeoJSON file
      #
      # @example
      #   border = AIPP::Border.from_file("/path/to/national_park.geojson")
      #   border.geometries
      #   # => [[#<AIXM::XY 45.12013320N 006.00953165E>, <AIXM::XY 45.12006703N 006.01574774E>]]
      def from_file(file)
        file = Pathname(file) unless file.is_a? Pathname
        fail(ArgumentError, "file must have extension .geojson") unless file.extname == '.geojson'
        geometries = JSON.load(file)['geometries'].map do |collection|
          collection['coordinates'].map do |long, lat|
            AIXM.xy(lat: lat, long: long)
          end
        end
        allocate.instance_eval do
          initialize(geometries)
          self
        end
      end

      # New border object from array of points
      #
      # The array must contain coordinate tuples in geographical order as
      # +latitude longitude+ separated by whitespace and/or commas.
      #
      # @param array [Array<Array<String>>] one or more arrays of coordinate pairs
      #
      # @example
      #   border = AIPP::Border.from_array([["45.1201332 6.00953165", "45.12006703 6.01574774"]])
      #   border.geometries
      #   # => [[#<AIXM::XY 45.12013320N 006.00953165E>, <AIXM::XY 45.12006703N 006.01574774E>]]
      def from_array(array)
        geometries = array.map do |collection|
          collection.map do |coordinates|
            lat, long = coordinates.split(/[\s,]+/)
            AIXM.xy(lat: lat.to_f, long: long.to_f)
          end
        end
        allocate.instance_eval do
          initialize(geometries)
          self
        end
      end
    end

    # @return [String]
    def inspect
      %Q(#<#{self.class} #{@geometries.count} geometries>)
    end

    # Whether the given geometry is closed or not
    #
    # A geometry is considered closed when it's first coordinate equals the
    # last coordinate.
    #
    # @param geometry_index [Integer] geometry to check
    # @return [Boolean] true if the geometry is closed or false otherwise
    def closed?(geometry_index:)
      geometry = @geometries[geometry_index]
      geometry.first == geometry.last
    end

    # Find a position on a geometry nearest to the given coordinates
    #
    # @param geometry_index [Integer] index of the geometry on which to search
    #   or +nil+ to search on all geometries
    # @param xy [AIXM::XY] coordinates to approximate
    # @return [AIPP::Border::Position] position nearest to the given coordinates
    def nearest(geometry_index: nil, xy:)
      position = nil
      min_distance = 21_000_000   # max distance on earth in meters
      @geometries.each.with_index do |geometry, g_index|
        next unless geometry_index.nil? || geometry_index == g_index
        geometry.each.with_index do |coordinates, c_index|
          distance = xy.distance(coordinates).dim
          if distance < min_distance
            position = Position.new(geometries: geometries, geometry_index: g_index, coordinates_index: c_index)
            min_distance = distance
          end
        end
      end
      position
    end

    # Get a segment of a geometry between the given starting and ending
    # positions
    #
    # The segment ends either at the given ending position or at the last
    # coordinates of the geometry. However, if the geometry is closed, the
    # segment always continues up to the given ending position.
    #
    # @param from_position [AIPP::Border::Position] starting position
    # @param to_position [AIPP::Border::Position] ending position
    # @return [Array<AIXM::XY>] array of coordinates describing the segment
    def segment(from_position:, to_position:)
      fail(ArgumentError, "both positions must be on the same geometry") unless from_position.geometry_index == to_position.geometry_index
      geometry_index = from_position.geometry_index
      geometry = @geometries[geometry_index]
      if closed?(geometry_index: geometry_index)
        up = from_position.coordinates_index.upto(to_position.coordinates_index)
        down = from_position.coordinates_index.downto(0) + (geometry.count - 2).downto(to_position.coordinates_index)
        geometry.values_at(*(up.count < down.count ? up : down).to_a)
      else
        geometry.values_at(*from_position.coordinates_index.up_or_downto(to_position.coordinates_index).to_a)
      end
    end

    private

    # Position defines an exact point on a border
    #
    # @example
    #   position = AIPP::Border::Position.new(
    #     geometries: border.geometries, geometry_index: 0, coordinates_index: 0
    #   )
    #   position.xy   # => #<AIXM::XY 45.12013320N 006.00953165E>
    class Position
      attr_accessor :geometry_index
      attr_accessor :coordinates_index

      def initialize(geometries:, geometry_index:, coordinates_index:)
        @geometries, @geometry_index, @coordinates_index = geometries, geometry_index, coordinates_index
      end

      # @return [String]
      def inspect
        %Q(#<#{self.class} xy=#{xy}>)
      end

      # Coordinates for this position
      #
      # @return [AIXM::XY, nil] coordinates or nil if the indexes don't exist
      def xy
        @geometries.dig(@geometry_index, @coordinates_index)
      end
    end
  end
end
