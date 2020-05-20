# require "docker"

# module CrystalTools


#   class CDockers
#     # include CrystalTools

#     def initialize()
#       @client = Docker::Client.new()
#     end

#     def containers()
#       @client.containers.list()
#     end
    
#     def create(name : String)
#       CDockerContainer.new self, name
#     end

#     #remove all containers who were created but not started
#     def cleanup
#       raise "not done yet"
#     end

#     #remove all containers
#     def deleteall()
#       `docker rm -f $(docker ps -a -q)`
#     end


#   end

#   class CDockerContainer
#     include CrystalTools

#     def initialize(@factory : CDockers, @name : String)

#       cs = @factory.containers
#       pp cs

#       @ipaddr = ""
#       @sshport = 0

#     end    

#   end


# end

