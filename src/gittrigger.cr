require "kemal"
require "json"
require "http/client"
require "./crystaltools"
require "openssl"
require "openssl/hmac"

module GitTrigger
  include CrystalTools

  REDIS = RedisFactory.client_get "gittriggers"
  GIT = GITRepoFactory.new

  
  
  @@jobs = {} of String => Array(String)
    
  def self.process_changes(serverurl : String = "")
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

  def self.start(@@secret : String)
    Kemal.config.port = 8080
    Kemal.run
  end

  def self.get_neph_script(name : String)

  end

  def self.subscribe(serverurl : String = "")
    #every minute call self.process_changes...

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
    signature = "sha1=" + OpenSSL::HMAC.hexdigest(:sha1, @@secret.not_nil!, body.to_json)
    githubsig= context.request.headers["X-Hub-Signature"]
    
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
    
    script = self.get_neph_script repo_name
    CrystalTools.log "Trigger: script: #{script}", 2

    unless script
      next
    end

    # if @@jobs.has_key?(repo_name)
    #   @@jobs[repo_name] << script
    # else
    #   @@jobs[repo_name] = Array{script}
    # end

    # if @@jobs[repo_name].size == 1
    #   spawn self.process_changes repo_name
    # end
  end
end
