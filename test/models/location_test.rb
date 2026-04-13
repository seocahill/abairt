require "test_helper"

class LocationTest < ActiveSupport::TestCase
  test "find_or_create_from_analysis returns existing location by name" do
    location = Location.find_or_create_from_analysis(name: "Belmullet")
    assert_equal locations(:belmullet), location
  end

  test "find_or_create_from_analysis creates new location with valid dialect_region" do
    location = Location.find_or_create_from_analysis(name: "Doohoma", dialect_region: "erris")
    assert_equal "erris", location.dialect_region
  end

  test "find_or_create_from_analysis falls back to inference when dialect_region is unknown" do
    # Regression: LLM returning 'unknown' caused ArgumentError on enum assignment
    assert_nothing_raised do
      location = Location.find_or_create_from_analysis(name: "SomePlace", dialect_region: "unknown")
      assert location.persisted?
      assert location.dialect_region.present?
    end
  end

  test "find_or_create_from_analysis falls back to inference when dialect_region is nil" do
    location = Location.find_or_create_from_analysis(name: "SomeOtherPlace")
    assert location.persisted?
    assert location.dialect_region.present?
  end

  test "infer_dialect_region returns other for unrecognised names" do
    assert_equal "other", Location.infer_dialect_region("Unknown Place XYZ")
  end
end
