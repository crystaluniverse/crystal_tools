require "kemal"
require "json"
require "http/client"
require "./crystaltools"
require "openssl"
require "openssl/hmac"
require "toml"
require "neph"

class RepoConfig	
  property name : String = ""	
  property organization : String = ""	
  property git_base_url : String = ""
  property pull_interval : Int64 = 300_i64

  def url
    return Path.new(@git_base_url, @organization, @name).to_s
  end
end	

class GitTriggerConfig	
  property id : String = ""	
  property slaves : Array(String) = Array(String).new	
  property port : Int64 = 8080_i64	
  property repos : Array(RepoConfig) = Array(RepoConfig).new	
  property exec_scripts : Array(String) = Array(String).new
end 


module GitTrigger
  include CrystalTools
  
  @@redis : RedisClient? = nil
  @@config : GitTriggerConfig? = nil
  
  # Dictionary of repo_url and list of neph files that need to be executed
    # this class variable is being monitoed by background fiber that executes whatever
    # comes there! and remove it from the stack!
    # (executor) is responsible for this
  @@jobs = {} of String => Array(String)

  def self.init
    @@git = GITRepoFactory.new
    @@redis = RedisFactory.client_get "gittriggers"
    
    # config object (updated automatically when user use `ct gittrigger reload` command)
    @@config = self.load_config

    
  end
  
  # Read config file into @@config
  # This function is called when you do `ct gittrigger reload`
  # and loads new config
  def self.load_config
    configfile = File.read("#{__DIR__}/config/gittrigger.toml")
    config = TOML.parse(configfile).as(Hash)

    server = config["server"].as(Hash)
    repos = config["repos"].as(Array)

    config_obj = GitTriggerConfig.new
    config_obj.port = server["port"].as(Int64)
    
    server["slaves"].as(Array).each do |slave|
      config_obj.slaves << slave.as(String)
    end
    puts server
    server["exec_scripts"].as(Array).each do |script|
      config_obj.exec_scripts << script.as(String)
    end

    config_obj.id = server["id"].as(String)

    repos.each do |repo|
      repo = repo.as(Hash)
      rc = RepoConfig.new
      rc.name = repo["name"].as(String)
      rc.organization = repo["organization"].as(String)
      rc.git_base_url = repo["git_base_url"].as(String)
      rc.pull_interval = repo["pull_interval"].as(Int64)
      config_obj.repos << rc
    end
    CrystalTools.log " - [GitTrigger Server] :: Configuration file loaded successfuly", 2
    return config_obj
  end

  # Fiber:: monitoring a repo
  # Pull each time interval
  # update loacal @@redis if there's any changes
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
        @@config.not_nil!.repos.each do |repo|
          repo_urls << repo.url
        end
        # make sure repo should be monitored, and get current time interval
        # if repo is no more there in config file, exit this fiber (unless main_watcher=false)
        # if main_watcher is false we know that this fiber is run as a subsequence event 
        # for a notification from master that there's a new repo added. so in this case, we need to keep running and
        # not exiting as we know for sure that this repo has no other watchers
        # if time interval for pulling changed, we use the new updated time

        index = repo_urls.index(repo_url)
        if index.nil? && main_watcher
          CrystalTools.log " - [GitTrigger Server] :: Repo watcher terminated for #{repo_url}", 2
          break
        end

        CrystalTools.log " - [GitTrigger Server] :: Repo watcher checking for updtes for #{repo_url}", 2
        
        repo = @@git.not_nil!.get url: "#{repo_url}"
        last_commit = repo.head
        last_commit_timestamp = repo.timestamp(last_commit)
        
        change = false
        update = {
          "url" => repo_url,
          "last_commit" => last_commit,
          "timestamp" => last_commit_timestamp,
          "id" => ""
        }

        # check repo state exists in @@redis
      
        if @@redis.not_nil!.exists("gittrigger:repos:#{repo_url}").as(Int64) == 0
          change = true
        else
          state = @@redis.not_nil!.hgetall("gittrigger:repos:#{repo_url}").map { |v| v.to_s }
          commit = state.index("last_commit").not_nil!
          if state[commit+1].to_s != last_commit
            change = true
          end
        end

         # If there's change, add to @@redis, schedule neph file, and notify subscribers
        if change
          CrystalTools.log " - [GitTrigger Server] :: Repo watcher updating state for #{repo_url}", 2
          update["id"] = @@redis.not_nil!.incr("gittrigger:repos:#{repo_url}:id").to_s
          @@redis.not_nil!.hmset("gittrigger:repos:#{repo_url}", update)
          self.schedule_job repo
          self.notify_slaves repo_url
        end
        
        if !main_watcher && !index.nil?
          break
        end

        time_interval = @@config.not_nil!.repos[index.not_nil!].pull_interval
        CrystalTools.log " - [GitTrigger Server] :: Repo watcher sleeping (#{time_interval}) s for #{repo_url}", 2
        sleep time_interval
      end
    end
  end

  # find neph file in the repo path, add to scheduled jobs if exists
  # this function is called, if there's a change in a repo
  # then we need to get the neph_file for that repo
  # and schedule it to be executed
  def self.schedule_job(gitrepo : GITRepo)
    repo_url = gitrepo.url.gsub("git@", "").rstrip(".git")
    
    @@config.not_nil!.exec_scripts.each do |script|
      base_path = "#{gitrepo.path}/.crystaldo"
      path = ""

      if script.ends_with?(".yaml") || script.ends_with?(".yml")
        if  File.exists?("#{base_path}/#{script}")
          path = "#{base_path}/#{script}"
        end
      elsif !script.includes?(".")
        if  File.exists?("#{base_path}/#{script}.yaml")
          path = "#{base_path}/#{script}.yaml"
        elsif File.exists?("#{base_path}/#{script}.yml")
          path = "#{base_path}/#{script}.yml"
        end
      end
      
      if !path
        next
      end
      
      CrystalTools.log " - [GitTrigger Server] :: Job Scheduler scheduling #{path} for execution for #{repo_url}", 2
      if @@jobs.has_key?(repo_url)
        @@jobs[repo_url] << path
      else
        @@jobs[repo_url] = Array{path}
      end
    end
  end

  # spawns fibers per repo, to check if it's updated
  # repos come from config file
  def self.monitor
    @@config.not_nil!.repos.each do |repo|
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

  def self.notify_slaves(repo_url)
    @@config.not_nil!.slaves.each do |slave|
      spawn do
        CrystalTools.log " - [GitTrigger Server] :: Notifier #{repo_url} updates are being sent to  #{slave}", 3
        res = HTTP::Client.post(
          "#{slave}/repos/#{repo_url}",
          headers: HTTP::Headers{"content_type" => "application/json"}
        )
        if res.status_code != 200
          CrystalTools.log " - [GitTrigger Server] :: Notifier #{repo_url} updates failed to be sent to #{slave}", 3
        end
      end
    end
  end
  
  # called by `ct gittrigger reload` command
  # it calls the local gittrigger instance via http
  # coz the ct gittrigger reload runs in another process
  # so it asks the local instance to reload config file
  def self.reload
    res = HTTP::Client.post(
      "http://127.0.0.1:#{@@config.not_nil!.port}/config/reload",
      headers: HTTP::Headers{"content_type" => "application/json"}
    )

    if res.status_code != 200
      CrystalTools.log " - [GitTrigger Server] :: Configuration reloaded failure", 3
    end
  end
  
  def self.start
    self.monitor
    self.executor
    Kemal.config.port = @@config.not_nil!.port.to_i32
    Kemal.run
  end

  #ex: /repos/github.com/hamdy/test
  post "/repos/*" do |context|
    repo_url = context.request.path.sub("/repos/", "").rstrip("/")
    self.monitor_repo(repo_url, false)
  end

  get "/repos/*" do |context|
    repo_url = context.request.path.sub("/repos/", "")
    if !context.params.query.has_key?("last_change")
      halt context, status_code: 404, response: "Not Found"
    end
    if @@redis.not_nil!.exists("gittrigger:repos:#{repo_url}").as(Int64) == 0
      halt context, status_code: 404, response: "Not Found"
    end
    last_change_id = context.params.query["last_change"].to_i32
    state = @@redis.not_nil!.hmget("gittrigger:repos:#{repo_url}", "id", "url", "last_commit", "timestamp").map {|v| v.to_s}
    if state[0].to_i32 == last_change_id
      halt context, status_code: 204, response: ""
    end
    {"id"=> state[0], "url" => state[1], "last_commit" => state[2], "timestamp" => state[3]}.to_json
  end

  
  # Reload config
  post "/config/reload" do |context|
    @@config = self.load_config
  end
end
