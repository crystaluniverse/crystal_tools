module CrystalTools
  class InstallerJumpscale

    def self.poetry_uninstall()

      pp `curl -sSL https://raw.githubusercontent.com/python-poetry/poetry/master/get-poetry.py > /tmp/get-poetry.py ; python3 /tmp/get-poetry.py --uninstall`

    end

    def self.install(reset = false, redo = false)
      CrystalTools.log "check base install", 2
      InstallerBase.install(reset: reset)

      if reset
        RedisFactory.done_reset(prefix: "installer.")
        if Executor.platform == "osx"
          `rm -rf ~/Library/Caches/pypoetry`
        end
      end      

      if ! Executor.cmd_exists_check("poetry")
        CrystalTools.log "install poetry", 2
        `curl -sSL https://raw.githubusercontent.com/python-poetry/poetry/master/get-poetry.py | python3`
      end

      if ! RedisFactory.done_check("installer.poetry.upgrade")
        `poetry self update`
        RedisFactory.done_set("installer.poetry.upgrade", expiration: 3600*48)
      end
      
      CrystalTools.log "get code of jumpscale sdk", 2

      self.update(reset, redo)

    end

    def self.update(reset = false, redo = false)

      gf=GITRepoFactory.new
      r = gf.get(url: "https://github.com/threefoldtech/js-sdk")
      r.pull(force = reset)

      pythonversion = Executor.exec("python -V", stdout: false)
      CrystalTools.log pythonversion, 3
      if pythonversion.includes?("ython 2") 
        CrystalTools.error "default python should be python3"
      end
      
      CrystalTools.log "install jumpscale in #{r.path}", 2
      if reset || redo || ! RedisFactory.done_check("installer.jumpscale.install")
        # `cd #{r.path} && poetry update`
        Executor.exec "cd #{r.path} && poetry update"
        Executor.exec "cd #{r.path} && poetry install"
        RedisFactory.done_set("installer.jumpscale.install", expiration: 3600)
      end      

    end


    def self.start()

      gf=GITRepoFactory.new
      r = gf.get(url: "https://github.com/threefoldtech/js-sdk")
      Executor.exec "cd #{r.path} && poetry shell && "

    end

  end

end
