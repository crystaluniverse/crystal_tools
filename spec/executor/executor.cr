require "../spec_helper"
include CrystalTools

describe CrystalTools do
  it "Long Execution" do
    Executor.exec(%(find /var/log/ -name *.log), stdout: false)
  end

  it "Short Execution with success" do
    Executor.exec(%(ls), stdout: true)
  end

  it "Short Execution error with die= false" do
    Executor.exec(%(lss), stdout: true, die: false)
  end

  it "Short Execution error with  die = true" do
    begin
      Executor.exec(%(lss), stdout: true)
      raise "Should have raised exception (died)"
    rescue
    end
    
  end

  
end
