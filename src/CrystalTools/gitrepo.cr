module CrystalTools
  HTTP_REPO_URL = /(https:\/\/)?(?P<provider>.+)(?P<suffix>\..+)\/(?P<account>.+)\/(?P<repo>.+)/
  SSH_REPO_URL  = /git@(?P<provider>.+)(?P<suffix>\..+)\:(?P<account>.+)\/(?P<repo>.+).git/

  class GITRepoFactory
    property codedir : String
    property repos : Hash(String, GITRepo)
    property repos_path : Hash(String, String)

    # property repos : Hash(String,GITRepo)
    # reponame's to path

    def initialize(@environment : String = "" )
      @repos = {} of String => GITRepo
      @repos_path = {} of String => String
      @codedir = Path["~/code"].expand(home: true).to_s
      @sshagent_loaded = Executor.exec_ok("ssh-add -l")
    end

    def repo_names_get(name : String)
      names = [] of String
      if name.includes?(',')
        names = name.split(",")
      elsif name.strip == ""
        if Dir.exists?("#{Dir.current}/.git")
          path = Dir.current
          name = Path[path].basename
          names = [name]
        else
          #find all repo's underneith the path we are in
          path = Dir.current
          Dir.glob("#{path}/**/*/.git").each do |p|
            if ! p.downcase.includes?("backup")  
              dirname = File.dirname(p)
              names << Path[dirname].basename
            end
          end
        end        
      else
        names = [name]
      end
      return names

    end

    # def repo_remember(r : GITRepo)
    #   redis = RedisFactory.core_get
    #   key = "crystaltools:git:latestreponame"
    #   redis.set "crystaltools:git:latestreponame", r.@name
    # end

    # def repo_get(name  : String = "")
    #   if name == ""
    #     redis = RedisFactory.core_get
    #     key = "crystaltools:git:latestreponame"
    #     name2 = redis.get "crystaltools:git:latestreponame"
    #     if name2 == nil
    #       name = ""
    #     else
    #       name = name2.as(String)
    #     end
    #   end 
    #   if name == ""
    #     raise "Cannot find repo, name not specified (or url or path)"
    #   end
    #   return get name: name
    # end

    def sshagent_loaded
      @sshagent_loaded
    end

    def get(name = "", path = "", url = "", branch = "", branchswitch = false, depth = 0)
      nameL = name.downcase


      if path == "" && url == "" && name == ""

        if Dir.exists?("#{Dir.current}/.git")
          path = Dir.current
        else
          #can see if there was a last repo remembered
          # return repo_get
          CrystalTools.error "Cannot get repo: path & url is empty, was name:#{name}"
        end
  
      end


      if name != ""
        if @repos.empty?
          CrystalTools.log "need to scan because we don't know which repo's exist"
          scan()
        end

        if @repos.has_key?(nameL)
          return @repos[nameL]
        end
        if @repos_path.has_key?(nameL)
          path = @repos_path[nameL]
        end
      end

      if path == "" && url == ""

        #can see if there was a last repo remembered
        # return repo_get
        CrystalTools.error "Cannot get repo: path & url is empty, was name:#{name}"
  
      end

      if name == "" && url == ""
        name = Path[path].basename
      end

      gr = GITRepo.new gitrepo_factory: self, name: name, path: path, url: url, branch: branch, branchswitch: branchswitch, environment: @environment, depth: depth
      repos[nameL] = gr
      gr.repo_ensure
      gr
    end

    private def dir_ignore_check(sub_path)
      if File.match?(".*", sub_path)
        return true
      end
      return false
    end

    # walk over code directory and find the repo's
    # is done is a very specific way, first provider dirs, then account dirs then repo dirs
    # is fast because only checks the possible locations
    def scan
      @repos_path = {} of String => String
      d = Dir.open(@codedir)
      # walk providers
      d.each do |provider_dir_sub|
        provider_dir = File.join([@codedir, provider_dir_sub])
        # CrystalTools.log provider_dir,1
        if File.directory? provider_dir
          if !dir_ignore_check(provider_dir_sub)
            # now walk the accounts
            d2 = Dir.open(provider_dir)
            d2.each do |account_dir_sub|
              account_dir = File.join([provider_dir, account_dir_sub])
              if File.directory? account_dir
                if !dir_ignore_check(account_dir_sub)
                  # now walk the repos
                  d3 = Dir.open(account_dir)
                  d3.each do |repo_dir_sub|
                    repo_dir = File.join([account_dir, repo_dir_sub])
                    if repo_dir_sub.downcase == "home"
                      name = account_dir_sub.downcase
                    else
                      name = repo_dir_sub.downcase
                    end
                    if !dir_ignore_check(repo_dir_sub)
                      # d4 = Dir.new(repo_dir)
                      if Dir.exists?("#{repo_dir}/.git")
                        # CrystalTools.log("  ... #{name}:  #{repo_dir}",4)
                        if @repos_path[name]? != nil
                          r1 = GITRepo.new gitrepo_factory: self, path: @repos_path[name]
                          r2 = GITRepo.new gitrepo_factory: self, path: repo_dir
                          CrystalTools.error "Found duplicate name in repo structure, each name needs to be unique\n#{@repos_path[name]} and #{repo_dir}"
                        end
                        @repos_path[name] = repo_dir
                      end
                    end
                  end
                end
              end
            end
          end
        end
      end
    end
  end

  # represents 1 specific repo on git, http & ssh can be used for updating the info
  # have nice enduser friendly operational message when it doesn't work
  class GITRepo
    property name : String
    property path : String
    property url : String
    property autocommit = false
    property branch = ""
    property branchswitch = false
    property account = ""
    property provider = "github"
    property provider_suffix = ".com"
    property environment = ""
    property depth = 0
    property gitrepo_factory : GITRepoFactory
    property pulled = false

    include CrystalTools

    def initialize(@gitrepo_factory, @name = "", @path = "", @url = "", @branch = "", @branchswitch = false, @environment = "", @depth = 0)

      if @path == "" && @url == ""
        error "path and url are empty #{name}"
      end

      Executor.cmd_exists_check "git"

      if @path != ""
        url_on_fs = try_read_url_from_path()
        # log url_on_fs
        # give url on fs priority
        if @url != "" && @url != url_on_fs
          CrystalTools.error "url mismatch: #{@url} and #{url_on_fs}"
        end
        if url_on_fs != ""
          @url = url_on_fs
        end
      end

      # put https in front if its not done yet
      if @url != ""
        if !@url.includes?("@") && !@url.starts_with?("https://")
          @url = "https://#{@url}"
        end
      else
        error "cannot initialize git repository if url not given: #{url}"
      end

      # initialize the git environment, parse the separate properties
      parse_provider_account_repo()

      if sshagent_loaded()
        if @url.starts_with?("http")
          change_to_ssh()
        end
        @url = url_as_ssh
      else
        @url = url_as_https
      end

      log "git repo on: #{@path}"
      log "git url: #{@url}"
    end

    # make sure we use ssh instead of https for pushing
    private def change_to_ssh
      re = /url = https:.*/m
      path_config = "#{@path}/.git/config"
      if Dir.exists? path_config
        CrystalTools.log "CHANGING TO SSH #{@url}", 2
        file_content = File.read path_config
        file_content = file_content.gsub(/url = https:.*/m, "url = #{url_as_ssh}.git")
        # puts file_content
        File.write("#{@path}/.git/config", file_content)
      end
    end

    # fetch the url from git config, if not exist return ''
    private def try_read_url_from_path
      Executor.exec("cd #{@path} && git config --get remote.origin.url", error_msg = "", stdout = true)
    end

    # returns true if sshagent is loaded with at least 1 key
    private def sshagent_loaded
      @gitrepo_factory.sshagent_loaded
    end

    # return the git url as https
    def url_as_https
      "https://#{@provider}#{@provider_suffix}/#{@account}/#{@name}"
    end

    # return the url in git ssh format
    def url_as_ssh
      "git@#{@provider}#{@provider_suffix}:#{@account}/#{@name}"
    end

    def base_dir
      if @environment != ""
        base_dir = "#{@gitrepo_factory.codedir}/#{@environment}/"
      else
        base_dir = "#{@gitrepo_factory.codedir}/"
      end
      base_dir
    end

    private def dir_account_ensure
      if @path == ""
        path0 = Path["#{base_dir}/#{@provider}/#{@account}"].expand(home: true)
        if ! Dir.exists?(path0.to_s)
          CrystalTools.log "create path: #{path0.to_s}",3
          Dir.mkdir_p(path0)
        end
        return path0.to_s
        
      else
        if ! Dir.exists? @path
          CrystalTools.error "Cannot find #{@path}, is where git repo should be."
        end
        return Path[@path].parent.to_s
      end

    end


    # get the parts of the url, parse to provider, account, name, path properties on obj
    private def parse_provider_account_repo
      # account_dir = ""
      # rewritten_url = @url # let's assume ssh is the default.
      path0 = ""
      if @url.starts_with?("http")
        m = HTTP_REPO_URL.match(@url)
        m.try do |validm|
          @provider = validm.not_nil!["provider"].to_s
          @provider_suffix = validm.not_nil!["suffix"].to_s
          @account = validm.not_nil!["account"].to_s
          @name = validm.not_nil!["repo"].to_s
          account_dir = dir_account_ensure()          
          path0 = File.join(account_dir, @name)
          CrystalTools.log "path0_http:#{account_dir}"
        end
        if path0 == ""
          CrystalTools.error "Could not parse url from http: \"#{@url}\""
        end
      elsif @url.starts_with?("git@")
        m = SSH_REPO_URL.match(@url)
        m.try do |validm|
          @provider = validm.not_nil!["provider"].to_s
          @account = validm.not_nil!["account"].to_s
          @name = validm.not_nil!["repo"].to_s
          account_dir = dir_account_ensure()
          path0 = File.join(account_dir, name)
          CrystalTools.log "path0_git:#{account_dir}"
        end
        if path0 == ""
          CrystalTools.error "Could not parse url from git: \"#{@url}\""
        end
      else
        CrystalTools.error "url needs to start with to be git or http. #{@url}"
      end
      CrystalTools.log @path, 2
      CrystalTools.log "#{path0}", 2
      CrystalTools.log "#{@url}", 2
      if @path == ""
        @path = path0
      elsif @path != path0 && path0 != ""
        CrystalTools.error "Path not on right location, found on fs: #{@path}, but should be #{path0}"
      end

    end

    # pull if needed, update if the directory is already there & .git found
    # clone if directory is not there
    # if there is data in there, ask to commit, ask message if @autocommit is on
    # if branchname specified, check branchname is the same, if not and @branchswitch is True switch branch, otherwise error
    def pull(force = false, msg = "")
      CrystalTools.log " - Pull #{@path}", 2
      repo_ensure() # handles the cloning, existence and the correct branch already.
      if force
        reset()
      else
        if changes()
          commit msg
        end
        Executor.exec("cd #{@path} && git pull")
      end
    end

    # will reset the repo, means create if not exists
    # will then reset to right branch & pull all changes
    # DANGEROUS: local changes will be overwritten
    def reset
      repo_ensure()
      `cd #{@path} && git clean -xfd && git checkout . && git checkout #{branch} && git pull`
      if !$?.success?
        raise "could not reset repo: #{@path}"
      end
    end

    # make sure the repository exists, if not will pull
    def repo_ensure
      unless Dir.exists?(@path)
        account_dir = dir_account_ensure()
        if account_dir != ""
          CrystalTools.log "cloning into #{@path} (dir did not exist)"
          if @depth != 0
            Executor.exec("cd #{account_dir} && git clone #{@url} --depth=#{@depth}  && cd #{@name} && git fetch")
          else
            Executor.exec("cd #{account_dir} && git clone #{@url}")
          end
          pull()
          return File.join(account_dir, @name)
        end        
      end
      return ""
    end

    # return the branchname from the repo on the filesystem, if it doesn't exist yet do an update
    private def branch_get
      raise "not implemented"
    end

    # check the local repo and compare to remote, if there is newer info remote return True, otherwise False
    def check_is_new
      raise "not implemented"
    end

    # delete the repo
    def delete
      FileUtils.rm_rf(@path)
    end

    # commit the new info, automatically do an add of all files
    def commit(msg : String)
      repo_ensure()
      if msg == ""
        puts "Changes found in repo: #{@path}"
        puts "please provide message:"
        msg = read_line.chomp
      end
      if changes()
        Executor.exec("cd #{@path} && git add . -A && git commit -m \"#{msg}\"")
      end
    end

    def changes
      res = Executor.exec("cd #{@path} && git status")
      if res.includes?("Untracked files")
        return true
      end
      if res.includes?("nothing to commit")
        return false
      end
      return true
    end

    # commit, pull, push
    def commit_pull_push(msg : String)
      # CrystalTools.log " - Pull/Push/Commit #{@path} : #{msg}", 2
      repo_ensure()
      # CrystalTools.log msg,3
      pull(msg: msg)
      push()
    end

    def push
      CrystalTools.log " - Push #{@path}", 2
      repo_ensure()
      Executor.exec("cd #{@path} && git push")
    end
  end
end
