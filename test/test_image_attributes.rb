require "minitest_helper"
require_relative "../plugins/site_builder"
module Builders; end
require_relative "../plugins/builders/image_attributes"

class TestImageAttributes < Bridgetown::Test
  UPLOADS = File.expand_path("../src/uploads", __dir__)

  it "reads image dimensions from PNG, JPEG, and WebP headers" do
    {
      "partners/plan-a-advisors.png" => [226, 72],
      "tori-rayne.jpg" => [400, 400],
      "causey-overview.webp" => [2880, 1358],
    }.each do |file, size|
      expect(Builders::ImageAttributes.dimensions(File.join(UPLOADS, file))) == size
    end
  end

  it "returns nil for files it can't read" do
    expect(Builders::ImageAttributes.dimensions(File.join(UPLOADS, "nope.png"))).must_be_nil
  end
end
