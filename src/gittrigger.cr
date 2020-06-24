require "kemal"
require "json"
require "http/client"
require "./crystaltools"
require "openssl"
require "openssl/hmac"
require "toml"
require "neph"
require "./gittrigger/models"

module GitTrigger
  include CrystalTools
  
  REDIS = RedisFactory.client_get "gittriggers"
  GIT = GITRepoFactory.new
  
  # config object (updated automatically when user use `ct gittrigger reload` command)
  @@config : GitTriggerConfig = self.load_config

  # Dictionary of repo_url and list of neph files that need to be executed
  # this class variable is being monitoed by background fiber that executes whatever
  # comes there! and remove it from the stack!
  # (executor) is responsible for this
  @@jobs = {} of String => Array(String)
  
  # Read config file into @@config
  # This function is called when you do `ct gittrigger reload`
  # and loads new config
  def self.load_config
    configfile = File.read("#{__DIR__}/gittrigger/config/gittrigger.toml")
    config = TOML.parse(configfile).as(Hash)

    server = config["server"].as(Hash)
    repos = config["repos"].as(Array)

    config_obj = GitTriggerConfig.new
    config_obj.port = server["port"].as(Int64)
    
    server["slaves"].as(Array).each do |slave|
      config_obj.slaves << slave.as(String)
    end

    config_obj.id = server["id"].as(String)

    repos.each do |repo|
      repo = repo.as(Hash)
      rc = RepoConfig.new
      rc.name = repo["name"].as(String)
      rc.url = repo["url"].as(String)
      rc.pull_interval = repo["pull_interval"].as(Int64)
      config_obj.repos << rc
    end
    CrystalTools.log " - [GitTrigger Server] :: Configuration file loaded successfuly", 2
    return config_obj
  end

  # Add subscriber to @@config
  # re-write the configuration file so when server restarts, subscribers can be there
  def self.add_subscriber(server_url : String)
    if @@config.slaves.index(server_url).nil?
      @@config.slaves.as(Array) << server_url
      
      CrystalTools.log " - [GitTrigger Server] :: Subscribers list updated with #{server_url}", 2
      
      configfile_path = "#{__DIR__}/gittrigger/config/gittrigger.toml"
      configfile = File.read(configfile_path)

      # Re-write configuration file with new values for future use
      io = IO::Memory.new
      configfile.split("\n").each do |line|
        if line.includes?("slaves")
          start = line.index("slaves")
          last = line.size - 1
          io << line.sub(start..last, "slaves = #{@@config.slaves.to_s}")
        else
          io << line
        end
        io << "\n"
      end
      File.write(configfile_path, io.to_s)
      CrystalTools.log " - [GitTrigger Server] :: Configuration file updated on disk successfuly", 2
    end
  end

  # Fiber:: monitoring a repo
  # Pull each time interval
  # update loacal redis if there's any changes
  # schedule neph tasks if there's any updates; ile append then to @@jobs[repo_url]
  # if run as main_watcher and repo not found any more, it terminates
  # if run as non main watcher mens it is run as a result of notification coming from
  # master that there's a change. in this case we check if repo exists before we 
  # update state and exit as there's already another watcher that mighr being sleeping
  # but if we found that this is a new repo. we need to update config, update config file
  # and we keep this watcher running to monitor future updates for that repo as we know for sure
  # that no other watchers running
  def self.monitor_repo(repo_url, main_watcher=true)
    spawn do
      loop do
        CrystalTools.log " - [GitTrigger Server] :: Repo watcher started for #{repo_url}", 2
        # get all repo urls
        repo_urls = [] of String
        @@config.repos.each do |repo|
          repo_urls << repo.url
        end
        # make sure repo should be monitored, and get current time interval
        # if repo is no more there in config file, exit this fiber (unless main_watcher=false)
        # if main_watcher is false we know that this fiber is run as a subsequence event 
        # for a notification from master that there's a new repo added. so in this case, we need to keep running and
        # not exiting as we know for sure that this repo has no other watchers
        # if time interval for pulling changed, we use the new updated time

        index = repo_urls.index(repo_url)
        new_repo = index.nil?
        if new_repo && main_watcher
          CrystalTools.log " - [GitTrigger Server] :: Repo watcher terminated for #{repo_url}", 2
          break
        end

        CrystalTools.log " - [GitTrigger Server] :: Repo watcher checking for updtes for #{repo_url}", 2
        
        repo = GIT.get url: "github.com/#{repo_url}"
        last_commit = repo.head
        last_commit_timestamp = repo.timestamp(last_commit)
        
        change = false
        update = {
          "url" => repo_url,
          "last_commit" => last_commit,
          "timestamp" => last_commit_timestamp,
          "id" => ""
        }

        # check repo state exists in redis
      
        if REDIS.exists("gittrigger:repos:#{repo_url}").as(Int64) == 0
          change = true
        else
          state = REDIS.hgetall("gittrigger:repos:#{repo_url}").map { |v| v.to_s }
          commit = state.index("last_commit").not_nil!
          if state[commit+1].to_s != last_commit
            change = true
          end
        end

         # If there's change, add to redis, schedule neph file, and notify subscribers
        if change
          CrystalTools.log " - [GitTrigger Server] :: Repo watcher updating state for #{repo_url}", 2
          update["id"] = REDIS.incr("gittrigger:repos:#{repo_url}:id").to_s
          REDIS.hmset("gittrigger:repos:#{repo_url}", update)
          self.schedule_job repo_url
        end
        
        # monitor_repo is called as a sbsequent trigger by master that there's a change
        # in this case, we have another repo watcher already running but might be sleeping
        # so we execute this once to update repo state and that's all 
        if !main_watcher
          # if it's new repo and only once is run as response to master
          # we need to keep that fiber running
          if !new_repo
            break
          else
            # update config with the new repo
            rc = RepoConfig.new
            rc.name = update["url"].split("/")[0]
            rc.url = update["url"]
            rc.pull_interval = 300
            @@config.repos << rc
            index = @@config.repos.size - 1
            # write new config
            io = IO::Memory.new
            configfile_path = "#{__DIR__}/gittrigger/config/gittrigger.toml"
            configfile = File.read(configfile_path)
            configfile.split("\n").each do |line|
              io << line
              io << "\n"
            end
            io << %([["repos"]])
            io << %(  name = "#{rc.name}")
            io << %(  url = "#{rc.url}")
            io << %(  pull_interval = "#{rc.pull_interval}")
            io << io << "\n"
            File.write(configfile_path, io.to_s)
            CrystalTools.log " - [GitTrigger Server] :: Configuration file updated on disk successfuly", 2
          end
        end

        time_interval = @@config.repos[index.not_nil!].pull_interval
        CrystalTools.log " - [GitTrigger Server] :: Repo watcher sleeping (#{time_interval}) s for #{repo_url}", 2
        sleep time_interval
      end
    end
  end

  # find neph file in the repo path, add to scheduled jobs if exists
  # this function is called, if there's a change in a repo
  # then we need to get the neph_file for that repo
  # and schedule it to be executed
  def self.schedule_job(repo_url : String)
    path = "#{GIT.path_code}/github/#{repo_url}/.crystaldo"
    if File.exists?("#{path}/main.yaml")
      path = "#{path}/main.yaml"
    elsif File.exists?("#{path}/main.yml")
      path = "#{path}/main.yml"
    else
      return
    end
    CrystalTools.log " - [GitTrigger Server] :: Job Scheduler adding jobs for #{repo_url}", 2
    if @@jobs.has_key?(repo_url)
      @@jobs[repo_url] << path
    else
      @@jobs[repo_url] = Array{path}
    end
  end

  # spawns fibers per repo, to check if it's updated
  # repos come from config file
  def self.monitor
    @@config.repos.each do |repo|
      self.monitor_repo repo.url
    end
  end

  # executes neph files in @@jobs for each repo
  def self.executor
    CrystalTools.log " - [GitTrigger Server] :: Job Executor Starting", 2
    spawn do
      loop do
        @@jobs.each do |repo_url, tasks|
          while tasks.size > 0
            neph_file_path = @@jobs[repo_url].pop
            neph = CrystalTools::NephExecuter.new neph_file_path
            CrystalTools.log " - [GitTrigger Server] :: Job Scheduler (START) execution #{neph_file_path} for #{repo_url}", 2
            neph.exec
            CrystalTools.log " - [GitTrigger Server] :: Job Scheduler (END) execution #{neph_file_path} for #{repo_url}", 2
          end
        end
        sleep 10
      end
    end
  end
  
  # called by `ct gittrigger reload` command
  # it calls the local gittrigger instance via http
  # coz the ct gittrigger reload runs in another process
  # so it asks the local instance to reload config file
  def self.reload
    res = HTTP::Client.post(
      "http://127.0.0.1:#{@@config.port}/config/reload",
      headers: HTTP::Headers{"content_type" => "application/json"}
    )

    if res.status_code != 200
      CrystalTools.log " - [GitTrigger Server] :: Configuration reloaded failure", 3
    end
  end
  
  # called by `ct gittrigger subscribe {server_url}` command
  def self.subscribe(server_url : String = "")
    res = HTTP::Client.post(
      "#{server_url}/subscriptions",
      headers: HTTP::Headers{"content_type" => "application/json"},
      body: {"subscriber" => @@config.id}.to_json
    )

    if res.status_code != 200
      CrystalTools.log " - [GitTrigger Server] :: Subscription failure. failed to add #{server_url}", 3
    end
  end

  def self.start
    self.monitor
    self.executor
    Kemal.config.port = @@config.port.to_i32
    Kemal.run
  end

  post "/repos/*" do |context|
    repo_url = context.request.path.sub("/repos/", "")
    self.monitor_repo(repo_url, false)
  end

  get "/repos/*" do |context|
    repo_url = context.request.path.sub("/repos/", "")
    if !context.params.query.has_key?("last_change")
      halt context, status_code: 404, response: "Not Found"
    end
    if REDIS.exists("gittrigger:repos:#{repo_url}").as(Int64) == 0
      halt context, status_code: 404, response: "Not Found"
    end
    last_change_id = context.params.query["last_change"].to_i32
    state = REDIS.hmget("gittrigger:repos:#{repo_url}", "id", "url", "last_commit", "timestamp")
    if state[2] == last_change_id
      halt context, status_code: 204, response: ""
    end
    {"id"=> state[0], "url" => state[1], "last_commit" => state[2], "timestamp" => state[3]}.to_json
  end

  
  # Reload config
  post "/config/reload" do |context|
    @@config = self.load_config
  end

  # subscriptions set
  post "/subscriptions" do |context|
    if !context.params.json.has_key?("subscriber")
      halt context, status_code: 409, response: "Bad Request"
    end
      puts context.params.json["subscriber"]
      self.add_subscriber context.params.json["subscriber"].as(String)
  end
end
