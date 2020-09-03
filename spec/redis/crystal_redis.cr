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

    RedisFactory.done_get("test").should eq(false)
    RedisFactory.done_set("test")
    RedisFactory.done_set("tee")
    RedisFactory.done_get("test").should eq(true)

    RedisFactory.done_reset("test")
    RedisFactory.done_get("test").should eq(false)

    (0..5).each do |nr|
      RedisFactory.done_set("test.#{nr}",1)
    end

    RedisFactory.done_list("test.").size.should eq(6)
    RedisFactory.done_list("test").size.should eq(6)
    RedisFactory.done_list("").size.should eq(7)
    RedisFactory.done_reset()
    RedisFactory.done_list("test.").size.should eq(0)

    RedisFactory.done_set("test",true)
    

  end

  it "jsonstor" do
    

  end

end
