require "redis"

module CrystalTools
  class SyncthingFactory
    # @@sessions = {} of String => SyncthingDir
    @@api_key = "" 

    # start syncthing in tmux
    def self.start()
      self.install
      #if not configured: configure syncthing with right API key
      #if configured: read the API key from config file
      #start the syncthing in tmux (use our tmux tools)
      #do a check that you can reach the syncthing API (rest)

    end

    # start syncthing in tmux
    def self.install()
        if !Executor.cmd_exists_check "syncthing"
          if Executor.platform == "osx"
            Executor.exec "brew install syncthing"
          else
            #
            Executor.package_install "syncthing"
          end
        end


    end

    # path is the path of the dir to add to syncthing
    def self.dir_add(name = "", path = "")
      #TODO: 
    end

    def self.dir_delete(name = "")
      #TODO:
    end


    # device is the unique id of the device who has rw access to it
    # rights: r and/or w (read/write)
    def self.dir_access_set(dir_name = "", device = "", rights  = "rw")
      #TODO: 
    end

    # device is the unique id of the device we want to dissalow to see a dir_name
    def self.dir_access_delete(dir_name = "", device = "")
      #TODO: 
    end


  end
end
