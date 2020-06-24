require "kemal"
require "json"
require "http/client"
require "./crystaltools"
require "openssl"
require "openssl/hmac"
require "toml"
require "neph"

module GitTrigger
  include CrystalTools

  REDIS = RedisFactory.client_get "gittriggers"
  GIT = GITRepoFactory.new

  
  
  @@jobs = {} of String => Array(String)
    
  def self.process_changes(serverurl : String = "")
    # CrystalTools.log "Processing jobs for: repo: #{repourl}", 2

    # local changes
    if serverurl == ""
      repos = self.ensure_repos
      repos.each do |repo|
        while @@jobs[repo].size > 0
          neph_file_path = @@jobs[repo].pop
          neph = CrystalTools::NephExecuter.new neph_file_path
          neph.exec
        end
      end

      
    end
    #get last_change id in your local redis , if unknown its 0
    #do http get request to the server (/github/changes)
    # now I get a dict with changed github repos, we get the urls
    #use GIT... to do a pull (get repo based on url)
    #now execute neph script in $repopath/.crystaldo/main.yaml
    #logs are done underneith $repopath/.crystaldo/.neph (by default), nothing todo

    #if not serverurl, check for local execution

    #FOR EACH CHANGE
    # r = GIT.get(url = )


  end

  def self.get_config
    configfile = File.read("#{__DIR__}/../src/config/gittrigger.toml")
    config = TOML.parse(configfile).as(Hash)
    return config["repos"].as(Array)
  end

  def self.ensure_repos
    reponames = [] of String
    self.get_config.each do |repo|
      repo = repo.as(Hash)
      GIT.get url: "github.com/#{repo["url"]}"
      reponame = repo["url"].as(String)
      reponames << reponame
      self.add_job reponame
    end
    REDIS.lpush("gittrigger:reponames", reponames)
    return reponames
  end
  
  def self.start
    self.process_changes ""
    Kemal.config.port = 8080
    Kemal.run
  end

  def self.add_job(repurl : String)
    path = "#{GIT.path_code}/github/#{repurl}/.crystaldo"
    if File.exists?("#{path}/main.yaml")
      path = "#{path}/main.yaml"
    elsif File.exists?("#{path}/main.yml")
      path = "#{path}/main.yml"
    else
      return
    end

    script = File.read(path)
    if @@jobs.has_key?(repurl)
      @@jobs[repurl] << path
    else
      @@jobs[repurl] = Array{path}
    end
    CrystalTools.log "Trigger: repo_name: #{repurl}", 2
    CrystalTools.log "Trigger: script: #{script}", 2

  end

  def self.subscribe(serverurl : String = "")
    spawn do
      loop do
        self.process_changes serverurl
        sleep 60
      end
    end
  end


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
    self.add_job url 
  end
end
