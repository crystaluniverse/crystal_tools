module CrystalTools
  HTTP_REPO_URL = /(https:\/\/)?(?P<provider>.+)(?P<suffix>\..+)\/(?P<account>.+)\/(?P<repo>.+)/
  SSH_REPO_URL  = /git@(?P<provider>.+)(?P<suffix>\..+)\:(?P<account>.+)\/(?P<repo>.+).git/

  class GITRepoFactory
    property repos : Hash(String, GITRepo)
    property environment : String
    property path_find : String
    property path_code : String
    property interactive = true

    def initialize(@environment = "", path = "")
      @repos = {} of String => GITRepo
      @sshagent_loaded = Executor.exec_ok("ssh-add -l")
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
      self.scan
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
          names = @repos.keys
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
        if @repos.empty?
          CrystalTools.log "need to scan because we don't know which repo's exist"
          scan()
        end

        if @repos.has_key?(nameL)
          return @repos[nameL]
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
      repos[nameL] = gr
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
      @repos_path = {} of String => String
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
          if @repos[name]? != nil
            # r1 = GITRepo.new gitrepo_factory: self, path: @repos_path[name]
            CrystalTools.error "Found duplicate name in repo structure, each name needs to be unique\n#{@repos[name].path} and #{repo_dir}"
          end
          @repos[name] = repo
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

    def to_s
      "GitRepo<#{@name} at #{@path}>"
    end

    def initialize(@gitrepo_factory, @name = "", @path = "", @url = "", @branch = "", @branchswitch = false, @depth = 0)
      if @path == "" && @url == ""
        error "path and url are empty #{name}"
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
        error "cannot initialize git repository if url not given: #{url}"
      end

      # initialize the git environment, parse the separate properties
      parse_provider_account_repo()

      # log @url, 2

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
      @gitrepo_factory.sshagent_loaded
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
      path0 = Path["#{gitrepo_factory.path_code}/#{@provider}/#{@account}"].expand(home: true)
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
      self.ensure
      if @gitrepo_factory.interactive
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
