require_relative '../../spec_helper'

describe AIPP::Border::Position do
  subject do
    AIPP::Border::Position.new(
      geometries: [
        [AIXM.xy(long: 0, lat: 0), AIXM.xy(long: 1, lat: 1), AIXM.xy(long: 2, lat: 2)],
        [AIXM.xy(long: 10, lat: 10), AIXM.xy(long: 11, lat: 11), AIXM.xy(long: 12, lat: 12)]
      ],
      geometry_index: 0,
      coordinates_index: 0
    )
  end

  describe :xy do
    it "returns the coordinates" do
      _(subject.xy).must_equal AIXM.xy(long: 0, lat: 0)
    end

    it "returns nil if the geometry index is out of bounds" do
      _(subject.tap { _1.geometry_index = 2 }.xy).must_be_nil
    end

    it "returns nil if the coordinates index is out of bounds" do
      _(subject.tap { _1.coordinates_index = 3 }.xy).must_be_nil
    end
  end
end

describe AIPP::Border do
  let :fixtures_dir do
    Pathname(__FILE__).join('..', '..', '..', 'fixtures')
  end

  # The border.geojson fixture defines three geometries:
  # * index 0: closed geometry circumventing the airfield of Pujaut
  # * index 1: closed geometry circumventing the village of Pujaut
  # * index 2: unclosed I-shaped geometry following the TGV from the S to N bridges over the Rhône
  # * index 3: unclosed U-shaped geometry around Île de Bartelasse from N to S end of Pont Daladier
  subject do
    AIPP::Border.new(fixtures_dir.join('border.geojson'))
  end

  describe :initialize do
    it "fails for files unless the extension is .geojson" do
      _{ AIPP::Border.new("/path/to/another.txt") }.must_raise ArgumentError
    end
  end

  describe :name do
    it "returns the upcased file name" do
      _(subject.name).must_equal 'BORDER'
    end
  end

  describe :closed? do
    it "returns true for closed geometries" do
      _(subject.closed?(geometry_index: 0)).must_equal true
      _(subject.closed?(geometry_index: 1)).must_equal true
    end

    it "returns false for unclosed geometries" do
      _(subject.closed?(geometry_index: 2)).must_equal false
      _(subject.closed?(geometry_index: 3)).must_equal false
    end
  end

  describe :nearest do
    let :point do
      AIXM.xy(lat: 44.008187986625636, long: 4.759397506713866)
    end

    it "finds the nearest position on any geometry" do
      position = subject.nearest(xy: point)
      _(position.geometry_index).must_equal 1
      _(position.coordinates_index).must_equal 12
      _(position.xy).must_equal AIXM.xy(lat: 44.01065725159039, long: 4.760427474975586)
    end

    it "finds the nearest postition on a given geometry" do
      position = subject.nearest(xy: point, geometry_index: 0)
      _(position.geometry_index).must_equal 0
      _(position.coordinates_index).must_equal 2
      _(position.xy).must_equal AIXM.xy(lat: 44.00269350325321, long: 4.7519731521606445)
    end
  end

  describe :segment do
    it "fails if positions are not on the same geometry" do
      from_position = AIPP::Border::Position.new(geometries: subject.geometries, geometry_index: 0, coordinates_index: 0)
      to_position = AIPP::Border::Position.new(geometries: subject.geometries, geometry_index: 1, coordinates_index: 0)
      _{ subject.segment(from_position: from_position, to_position: to_position) }.must_raise ArgumentError
    end

    it "returns shortest segment on an unclosed I-shaped geometry" do
      from_position = subject.nearest(xy: AIXM.xy(lat: 44.002940457248556, long: 4.734249114990234))
      to_position = subject.nearest(xy: AIXM.xy(lat: 44.07155380033749, long: 4.7687530517578125), geometry_index: from_position.geometry_index)
      _(subject.segment(from_position: from_position, to_position: to_position)).must_equal [
        AIXM.xy(lat: 44.00516299694704, long: 4.7371673583984375),
        AIXM.xy(lat: 44.02195282780904, long: 4.743347167968749),
        AIXM.xy(lat: 44.037503870182896, long: 4.749870300292969),
        AIXM.xy(lat: 44.05379106204314, long: 4.755706787109375),
        AIXM.xy(lat: 44.070073775703484, long: 4.7646331787109375)
      ]
    end

    it "returns shortest segment on an unclosed U-shaped geometry" do
      from_position = subject.nearest(xy: AIXM.xy(lat: 43.96563876212758, long: 4.8126983642578125))
      to_position = subject.nearest(xy: AIXM.xy(lat: 43.956989327857265, long: 4.83123779296875), geometry_index: from_position.geometry_index)
      _(subject.segment(from_position: from_position, to_position: to_position)).must_equal [
        AIXM.xy(lat: 43.9646503190861, long: 4.815788269042969),
        AIXM.xy(lat: 43.98614524381678, long: 4.82025146484375),
        AIXM.xy(lat: 43.98491011404692, long: 4.840850830078125),
        AIXM.xy(lat: 43.99479043262446, long: 4.845314025878906),
        AIXM.xy(lat: 43.98367495857784, long: 4.8538970947265625),
        AIXM.xy(lat: 43.967121395851485, long: 4.851493835449218),
        AIXM.xy(lat: 43.96069638244953, long: 4.8442840576171875),
        AIXM.xy(lat: 43.96069638244953, long: 4.829521179199219)
      ]
    end

    it "returns shortest segment ignoring endings on a closed geometry" do
      from_position = subject.nearest(xy: AIXM.xy(lat: 44.00022390676026, long: 4.789009094238281))
      to_position = subject.nearest(xy: AIXM.xy(lat: 43.99800118202362, long: 4.765834808349609), geometry_index: from_position.geometry_index)
      _(subject.segment(from_position: from_position, to_position: to_position)).must_equal [
        AIXM.xy(lat: 44.00077957493397, long: 4.787635803222656),
        AIXM.xy(lat: 43.99818641226534, long: 4.784030914306641),
        AIXM.xy(lat: 43.994111213373934, long: 4.78205680847168),
        AIXM.xy(lat: 44.00115001749186, long: 4.777421951293944),
        AIXM.xy(lat: 44.002940457248556, long: 4.770212173461914)
      ]
    end

  end
end
