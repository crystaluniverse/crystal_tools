require "json"

class Location
    include JSON::Serializable
    @[JSON::Field(key: "lat")]
    property latitude : Float64  
    property longitude : Float64
end

class House
    include JSON::Serializable
    property address : String
    property location : Location?
end


require "../spec_helper"

it "jsontest" do

    house = House.from_json(%({"address": "Crystal Road 1234", "location": {"lat": 12.3, "longitude": 34.5}}))
    house.address  # => "Crystal Road 1234"
    house.location # => #<Location:0x10cd93d80 @latitude=12.3, @longitude=34.5>
    house.to_json  # => %({"address":"Crystal Road 1234","location":{"lat":12.3,"lng":34.5}})

    houses = Array(House).from_json(%([{"address": "Crystal Road 1234", "location": {"lat": 12.3, "longitude": 34.5}}]))
    houses.size    # => 1
    pp houses.to_json # => %([{"address":"Crystal Road 1234","location":{"lat":12.3,"lng":34.5}}])

end

