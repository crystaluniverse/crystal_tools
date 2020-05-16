require "docker"

module CrystalTools
  VERSION = "0.1.0"


  class Dockers
    include CrystalTools

    def initialize(@name : String)
      @client = Docker::Client.new()
    end

    def self.containers()
      @client.containers.list()
    end
    
    def create(name: String)
      DockerContainer name
    end

  end

  class DockerContainer
    include CrystalTools

    

    def initialize(@name : String)

      cs = Docker.containers
      pp cs

      @ipaddr = ""
      @sshport = 0

    end    

  end


end

