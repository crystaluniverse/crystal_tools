require "../spec_helper"
include CrystalTools

describe CrystalTools do
  it "GitRepoFactory" do
    GITRepoFactory.scanned?.should eq(false)
    gitrepo_factory = GITRepoFactory.new
    GITRepoFactory.scanned?.should eq(true)
    gitrepo_factory = GITRepoFactory.new
  end


end
