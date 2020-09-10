module CrystalTools
  class InstallerJumpscale

    def self.poetry_uninstall()

      pp `curl -sSL https://raw.githubusercontent.com/python-poetry/poetry/master/get-poetry.py > /tmp/get-poetry.py ; python3 /tmp/get-poetry.py --uninstall`

    end

    def self.install(reset = false)
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
        puts `curl -sSL https://raw.githubusercontent.com/python-poetry/poetry/master/get-poetry.py | python3`
      end

      if ! RedisFactory.done_check("installer.poetry.upgrade")
        puts `poetry self update`
        RedisFactory.done_set("installer.poetry.upgrade", expiration: 3600*48)
      end
      
      CrystalTools.log "get code of jumpscale sdk", 2

      gf=GITRepoFactory.new
      r = gf.get(url: "https://github.com/threefoldtech/js-sdk")
      r.pull() #TODO: wrong, does also a push which it should not do

      pythonversion = Executor.exec("python -V", stdout: false)
      CrystalTools.log pythonversion, 3
      if pythonversion.includes?("ython 2") 
        CrystalTools.error "default python should be python3"
      end
      CrystalTools.log "install poetry", 2
      pp r.path

      `cd #{r.path} && poetry update`
      `cd #{r.path} && poetry update`
      # redis = RedisFactory.core_get

      
    end

  end

end
