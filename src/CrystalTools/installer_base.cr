module CrystalTools
  class InstallerBase
    def self.install(reset = false)

      #first need to check brew is installed
      if Executor.platform == "osx"
        if ! Executor.cmd_exists_check("brew")
          `/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"`
        end
      end

      RedisFactory.core_get() #make sure redis installed

      if reset
        RedisFactory.done_reset(prefix: "package.")
      end

      toinstall = ["git","nginx", "tmux", "python3"]

      if Executor.platform == "osx"
        if ! Executor.cmd_exists_check("brew")
          `/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"`
          if ! Executor.cmd_exists_check("brew")
            CrystalTools.error "brew has to be installed"
          end
        end
        toinstall << "mkcert"
      end      

      if Executor.platform == "ubuntu"
        toinstall << "python3-venv"
        toinstall << "python3-pip "
      end 
       
      Executor.package_upgrade()
      toinstall.each do |cmd|
        Executor.package_install cmd
      end
    end


  end
end
