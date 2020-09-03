require "../spec_helper"
include CrystalTools

describe CrystalTools do
  it "Long Execution" do
    Executor.exec(%(find /home -name hamdy), stdout: false)
  end

  it "Long Execution2" do
    Executor.exec(%(find /home -name xx), stdout: false)
  end


end
