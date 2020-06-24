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
  
  
  @@config : GitTriggerConfig = self.load_config
  @@jobs = {} of String => Array(String)
  
  # Read config file into class property
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

    repos.each do |repo|
      repo = repo.as(Hash)
      rc = RepoConfig.new
      rc.name = repo["name"].as(String)
      rc.url = repo["url"].as(String)
      rc.pull_interval = repo["pull_interval"].as(Int64)
      config_obj.repos << rc
    end
    puts config_obj
    return config_obj
  end

  # Fiber:: monitoring a repo
  # Pull each time interval
  # update loacal redis if there's any changes
  # schedule neph tasks if there's any updates
  # need a way to update or terminate if not valid any more, i.e repo removed from config
  def self.monitor_repo(repo_url)
    spawn do
      loop do
        puts "loop start"
        # get all repo urls
        repo_urls = [] of String
        @@config.repos.each do |repo|
          repo_urls << repo.url
        end
        # make sure repo should be monitored, and get current time interval
        index = repo_urls.index(repo_url)
        if index.nil?
          break
        end
        CrystalTools.log "Repo Watcher [#{repo_url}] Checking for updates", 2
        
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
          update["id"] = REDIS.incr("gittrigger:repos:#{repo_url}:id").to_s
          REDIS.hmset("gittrigger:repos:#{repo_url}", update)
          self.schedule_job repo_url
        end
        
        time_interval = @@config.repos[index].pull_interval
        CrystalTools.log "Repo Watcher [#{repo_url}] goint to sleep for #{time_interval}", 2
        sleep time_interval
      end
    end
  end

  # find neph file in the repo path, add to scheduled jobs if exists
  def self.schedule_job(repo_url : String)
    path = "#{GIT.path_code}/github/#{repo_url}/.crystaldo"
    if File.exists?("#{path}/main.yaml")
      path = "#{path}/main.yaml"
    elsif File.exists?("#{path}/main.yml")
      path = "#{path}/main.yml"
    else
      return
    end

    script = File.read(path)
    if @@jobs.has_key?(repo_url)
      @@jobs[repo_url] << path
    else
      @@jobs[repo_url] = Array{path}
    end
    CrystalTools.log "Trigger: repo_name: #{repo_url}", 2
  end

  def self.monitor
    @@config.repos.each do |repo|
      self.monitor_repo repo.url
    end
  end

  def self.scheduler
    CrystalTools.log "Scheduler: started", 2
    spawn do
      loop do
        @@jobs.each do |repo, tasks|
          while tasks.size > 0
            neph_file_path = @@jobs[repo].pop
            neph = CrystalTools::NephExecuter.new neph_file_path
            neph.exec
          end
        end
        sleep 10
      end
    end
  end
  
  # called by ct gittrigger reload command
  def self.reload
    res = HTTP::Client.post(
      "http://127.0.0.1:#{@@config.port}/config/reload",
      headers: HTTP::Headers{"content_type" => "application/json"}
    )

    if res.status_code == 200
      CrystalTools.log "Config reloaded", 2
    else
      CrystalTools.log "Config reload failure", 5
    end
  end
  
  def self.start
    self.monitor
    self.scheduler
    Kemal.config.port = @@config.port.to_i32
    Kemal.run
  end

  def self.subscribe(serverurl : String = "");end


  get "/github" do |context|
    if !context.params.query.has_key?("repo_name") || !context.params.query.has_key?("last_change")
      halt context, status_code: 404, response: "Not Found"
    end

    repo_name = context.params.query["repo_name"]
    last_change_id = context.params.query["last_change"].to_i32
    
    changes = REDIS.hmget("gittrigger:changes:#{repo_name}", "url", "last_commit", "timestamp", "id" )
    
    if changes.includes?(nil)
      halt context, status_code: 404, response: "Not Found"
    end
    if changes[3].as(String).to_i32 <= last_change_id
      halt context, status_code: 204, response: ""
    end

    {"url" => changes[0], "last_commit": changes[1], "timestamp": changes[2], "id": changes[3]}.to_json
  end

  post "/github" do |context|
    body = context.params.json
    # signature = "sha1=" + OpenSSL::HMAC.hexdigest(:sha1, @@secret.not_nil!, body.to_json)
    # githubsig= context.request.headers["X-Hub-Signature"]
    
    payload = body["repository"].as(Hash)
    repo_name = payload["full_name"].to_s
    url = payload["html_url"].to_s
    last_commit = body["head_commit"].as(Hash)["id"].to_s
    timestamp = payload["pushed_at"].to_s

    tid = REDIS.incr("gittrigger:changes:#{repo_name}:id").to_i32
    # REDIS.lpush("gittrigger:repos:#{repo_name}", {
    REDIS.hmset("gittrigger:changes:#{repo_name}", {
      "url" => url,
       "last_commit": last_commit,
        "timestamp": timestamp,
        "id": tid
      })
    
    puts "\n\n\n"
    CrystalTools.log "Trigger: repo_name: #{repo_name}", 2
  end

   # Reload config
  post "/config/reload" do |context|
    @@config = self.load_config
    CrystalTools.log "Config Reloaded: #{@@config}", 2
  end
end
