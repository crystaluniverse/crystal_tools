require "msgpack"

module CrystalTools
  HTTP_REPO_URL = /(https:\/\/)?(?P<provider>.+)(?P<suffix>\..+)\/(?P<account>.+)\/(?P<repo>.+)/
  SSH_REPO_URL  = /git@(?P<provider>.+)(?P<suffix>\..+)\:(?P<account>.+)\/(?P<repo>.+).git/

  # struct GitConfig

  # end
  #msgpack serialize and put in redis 

  class GITRepoFactory   
    @@redis : CrystalTools::RedisClient =  RedisFactory.core_get()

    property environment : String
    property path_find : String
    property path_code : String
    property interactive = true
    

    def scanned
      @@redis.get("gitrepos::scanned") == "true"
    end

    def set_scanned
      @@redis.set("gitrepos::scanned", true)
    end

    def add(reponame, repo)
      CrystalTools.log "-  Caching repo (#{reponame})", 2
      @@redis.hset("gitrepos::repos", reponame, repo)
    end

    def remove(reponame)
      CrystalTools.log "-  Remove repo (#{reponame}) from Cache", 2
      @@redis.hdel("gitrepos::repos", reponame)
    end

    def repos
      data = @@redis.hgetall("gitrepos::repos")
      result = Hash(String, GITRepo).new
      i = 0
      j = 1
      data.each do |item|
        if j > data.size
          break
        end

        reponame = data[i].as(String)
        repo = data[j].as(String)
        repo_obj = GITRepo.from_msgpack(repo.to_slice)
        repo_obj.gitrepo_factory = self
        result[reponame] = repo_obj 
        i +=2
        j += 2
      end
      result
    end

    def initialize(@environment = "", path = "", reload=false)
      @sshagent_loaded = Executor.exec_ok("ssh-add -l") #check if there is an sshagent
      if path == "."
        @path_find = Dir.current
      elsif path == ""
        @path_find = Path["~/code"].expand(home: true).to_s
      else
        @path_find = path
      end
      @path_code = Path["~/code"].expand(home: true).to_s
      if @environment != ""
        @path_code = "#{@path_code}_#{@environment}"
      end
      if reload || !self.scanned
        CrystalTools.log "Scanning repos", 2
        self.scan
        self.set_scanned
      end
    end

    # go from comma separated names to repo names, or if not specified go to the current dir
    # if empty and not in .git dir then will return all names known to the factory
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
          names = self.repos.keys
        end
      else
        names = [name]
      end
      return names
    end

    def sshagent_loaded
      @sshagent_loaded
    end

    def get(name = "", path = "", url = "", branch = "", branchswitch = false, depth = 0)
      nameL = name.downcase

      if path == "" && url == "" && name == ""
        if Dir.exists?("#{Dir.current}/.git")
          path = Dir.current
        else
          # can see if there was a last repo remembered
          # return repo_get
          CrystalTools.error "Cannot get repo: path & url is empty, was name:#{name}"
        end
      end

      if name != ""
        if self.repos.empty?
          CrystalTools.log "need to scan because we don't know which repo's exist"
          scan()
        end

        if self.repos.has_key?(nameL)
          return self.repos[nameL]
        end
      end

      if path == "" && url == ""
        # can see if there was a last repo remembered
        # return repo_get
        CrystalTools.error "Cannot get repo: path & url is empty, was name:#{name}"
      end

      if name == "" && url == ""
        name = Path[path].basename
      end

      gr = GITRepo.new gitrepo_factory: self, name: name, path: path, url: url, branch: branch, branchswitch: branchswitch, depth: depth
      self.repos[nameL] = gr
      gr.ensure
      gr
    end

    protected def dir_ignore_check(sub_path)
      if File.match?(".*", sub_path)
        return true
      end
      return false
    end

    # walk over code directory and find the repo's
    # is done is a very specific way, first provider dirs, then account dirs then repo dirs
    # is fast because only checks the possible locations
    protected def scan
      CrystalTools.log("Scanning git repos from file system")
      repos = {} of String => GITRepo
      name = ""
      Dir.glob("#{@path_find}/**/*/.git").each do |repo_path|
        # make sure dir's starting with _ are skipped (e.g. can be used for backup)
        if !repo_path.includes? "/_"
          repo_dir = File.dirname(repo_path)

          name = Path[repo_dir].basename.downcase
          if name == "home"
            name = Path[File.dirname(repo_dir)].basename.downcase
          end
          CrystalTools.log("  ... #{name}:  #{repo_dir}")
          repo = GITRepo.new gitrepo_factory: self, path: repo_dir, name: name
          if repos[name]? != nil
            CrystalTools.error "Found duplicate name in repo structure, each name needs to be unique\n#{repos[name].path} and #{repo_dir}"
          end
          repos[name] = repo
        end
      end
      repos.each do |reponame, repo|
        self.add(reponame, String.new(repo.to_msgpack))
      end
    end
  end

  # represents 1 specific repo on git, http & ssh can be used for updating the info
  # have nice enduser friendly operational message when it doesn't work
  class GITRepo
    
    include MessagePack::Serializable

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

    @[MessagePack::Field(ignore: true)]
    property gitrepo_factory : GITRepoFactory? = nil
    
    property pulled = false

       
    def to_s
      "GitRepo<#{@name} at #{@path}>"
    end

    def initialize(@gitrepo_factory, @name = "", @path = "", @url = "", @branch = "", @branchswitch = false, @depth = 0)
      if @path == "" && @url == ""
        CrystalTools.error "path and url are empty #{name}"
      end

      Executor.cmd_exists_check "git"

      if @path != ""
        url_on_fs = try_read_url_from_path()
        # log url_on_fs, 2
        # give url on fs priority
        # if @url != "" && @url != url_on_fs
        #   CrystalTools.error "url mismatch: #{@url} and #{url_on_fs}"
        # end
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
        CrystalTools.error "cannot initialize git repository if url not given: #{url}"
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

      CrystalTools.log "git repo on: #{@path}"
      CrystalTools.log "git url: #{@url}"
    end

    # make sure we use ssh instead of https for pushing
    private def change_to_ssh
      # re = /url = https:.*/m
      path_config = "#{@path}/.git/config"
      CrystalTools.log "CHANGING TO SSH #{@url}"
      CrystalTools.log "config path '#{path_config}''"
      if File.exists? path_config
        file_content = File.read path_config
        file_content = file_content.gsub(/url = https:.*/m, "url = #{url_as_ssh}")
        File.write("#{@path}/.git/config", file_content)
      end
    end

    # fetch the url from git config, if not exist return ''
    private def try_read_url_from_path
      Executor.exec("cd #{@path} && git config --get remote.origin.url", error_msg = "", stdout = true)
    end

    # returns true if sshagent is loaded with at least 1 key
    private def sshagent_loaded
      @gitrepo_factory.not_nil!.sshagent_loaded
    end

    # return the git url as https
    def url_as_https
      "https://#{@provider}#{@provider_suffix}/#{@account}/#{@name}"
    end

    # return the url in git ssh format
    def url_as_ssh
      "git@#{@provider}#{@provider_suffix}:#{@account}/#{@name}.git"
    end

    private def dir_account_ensure
      path0 = Path["#{gitrepo_factory.not_nil!.path_code}/#{@provider}/#{@account}"].expand(home: true)
      unless Dir.exists?(path0.to_s)
        CrystalTools.log "create path: #{path0.to_s}", 3
        Dir.mkdir_p(path0)
      end
      return path0.to_s
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
          path0 = File.join(account_dir, @name.sub(".git", ""))
          CrystalTools.log "path0_http:#{account_dir}"
        end
        if path0 == ""
          CrystalTools.error "Could not parse url from http: \"#{@url}\""
        end
      elsif @url.starts_with?("git@")
        @url = @url + ".git" unless @url.ends_with?(".git")
        m = SSH_REPO_URL.match(@url)
        m.try do |validm|
          @provider = validm.not_nil!["provider"].to_s
          @account = validm.not_nil!["account"].to_s
          @name = validm.not_nil!["repo"].to_s
          account_dir = dir_account_ensure()
          path0 = File.join(account_dir, name.sub(".git", ""))
          CrystalTools.log "path0_git:#{account_dir}"
        end
        if path0 == ""
          CrystalTools.error "Could not parse url from git: \"#{@url}\""
        end
      else
        CrystalTools.error "url needs to start with to be git or http. #{@url}\nFor #{@path}"
      end
      # CrystalTools.log "#{path0}"
      CrystalTools.log "#{@url}"
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
    def pull(force = false, msg = "", interactive = true)
      CrystalTools.log " - Pull #{@path}", 2
      self.ensure # handles the cloning, existence and the correct branch already.

      if force
        reset()
      else
        if changes()
          if msg != "" || interactive
            commit msg
          else
            raise "cannot commit if msg not given and interactive is false"
          end
        end
        Executor.exec("cd #{@path} && git pull")
      end
    end

    # will reset the repo, means create if not exists
    # will then reset to right branch & pull all changes
    # DANGEROUS: local changes will be overwritten
    def reset
      self.ensure
      `cd #{@path} && git clean -xfd && git checkout . && git checkout #{branch} && git pull`
      if !$?.success?
        raise "could not reset repo: #{@path}"
      end
    end

    # make sure the repository exists, if not will pull
    def ensure

      unless Dir.exists?(@path)
        account_dir = dir_account_ensure()
        if account_dir != ""
          CrystalTools.log "cloning into #{@path} (dir did not exist)"
          cmd = "cd #{account_dir} && git clone #{@url}"

          if @branch != ""
            cmd += " -b #{@branch}"
          end

          if @depth != 0
            cmd += " --depth=#{@depth}  && cd #{@name} && git fetch"
          end

          Executor.exec(cmd)
          pull()
          self.gitrepo_factory.not_nil!.add(@name, self)
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
      self.gitrepo_factory.not_nil!.remove(@name)
      FileUtils.rm_rf(@path)
    end

    # commit the new info, automatically do an add of all files
    def commit(msg : String)
      self.ensure
      if @gitrepo_factory.not_nil!.interactive
        if msg == ""
          puts "Changes found in repo: #{@path}"
          puts "please provide message:"
          msg = read_line.chomp
        end
        if changes()
          Executor.exec("cd #{@path} && git add . -A && git commit -m \"#{msg}\"")
        end
      else
        CrystalTools.log " - make sure to enable interactive to be able to commit changes in #{@path}", 2
      end
    end

    def changes
      res = Executor.exec("cd #{@path} && git status")
      if res.includes?("Untracked files")
        return true
      end
      if res.includes?("Your branch is ahead of")
        push()
      end
      if res.includes?("nothing to commit")
        return false
      end
      return true
    end

    # commit, pull, push
    def commit_pull_push(msg : String)
      # CrystalTools.log " - Pull/Push/Commit #{@path} : #{msg}", 2
      self.ensure
      # CrystalTools.log msg,3
      pull(msg: msg)
      push()
    end

    def push
      CrystalTools.log " - Push #{@path}", 2
      self.ensure
      Executor.exec("cd #{@path} && git push")
    end

    # last commit
    def head
      CrystalTools.log " - Git HEAD #{@path}", 2
      Executor.exec("cd #{@path} && git rev-parse HEAD")
    end

    # timestamp of commit
    def timestamp(commit)
      CrystalTools.log " - Git #{@path} timestamp for commit #{commit}", 2
      Executor.exec("cd #{@path} && git show -s --format=%ct #{commit}")
    end
  end
end
