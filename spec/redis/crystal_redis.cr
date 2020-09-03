require "../spec_helper"
include CrystalTools

describe CrystalTools do
  it "redis done" do

    RedisFactory.core_stop()
    v = RedisFactory.core_exists()
    v.should eq(false)

    r = RedisFactory.core_get()
    v = RedisFactory.core_exists()
    v.should eq(true)

    #do a ping check redis exists
    r.ping().should eq("PONG")

    RedisFactory.core_reset()

    # epoch = Time.local.to_unix()

    RedisFactory.done_check("test").should eq(false)
    RedisFactory.done_set("test")
    RedisFactory.done_set("tee")
    RedisFactory.done_check("test").should eq(true)

    RedisFactory.done_reset("test")
    RedisFactory.done_check("test").should eq(false)

    (0..5).each do |nr|
      RedisFactory.done_set("test.#{nr}",1)
    end

    RedisFactory.done_list("test.").size.should eq(6)
    RedisFactory.done_list("test").size.should eq(6)
    RedisFactory.done_list("").size.should eq(7)
    RedisFactory.done_reset()
    RedisFactory.done_list("test.").size.should eq(0)

    RedisFactory.serialize("hey").should eq("hey")
    RedisFactory.serialize(3).should eq(3)
    RedisFactory.serialize(true).should eq(true)
    RedisFactory.serialize(false).should eq(false)
    RedisFactory.serialize(nil).should eq(nil)    

    RedisFactory.done_set("a")
    RedisFactory.done_check("a").should eq(true)
    RedisFactory.done_get("a").should eq(nil)
    RedisFactory.done_set("b", val: 10)
    RedisFactory.done_check("b").should eq(true)
    RedisFactory.done_get("b").should eq("10")
  end

  it "jsonstor" do
    

  end

end
