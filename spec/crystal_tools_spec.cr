require "./spec_helper"
require "toml"

describe CrystalTools do
  it "gittriggerstoml" do
    file = File.read("#{__DIR__}/../src/config/gittrigger.toml")
    config = TOML.parse(file)
    puts config
  end
end
