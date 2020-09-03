require "../spec_helper"
require "toml"

describe CrystalTools do
  it "gittriggerstoml" do
    o = IO::Memory.new
    file = File.read("#{__DIR__}/../../src/config/gittrigger.toml")
    file.split("\n").each do |line|
      o << line
      o << "\n"
    end
    puts o.to_s
    config = TOML.parse(file)
  end
end
