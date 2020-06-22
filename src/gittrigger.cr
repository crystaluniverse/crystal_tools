require "kemal"
require "json"
require "http/client"
require "./crystaltools"

module GitTrigger
  include CrystalTools

  REDIS = RedisFactory.core_get
  GIT = GITRepoFactory.new

  
  @@jobs = {} of String => Array(String)
  #TODO: how to have a redis client without having to re-initialize
  # @@redis = RedisFactory.core_get of RedisClient
  
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

  def self.start
    Kemal.config.port = 8080
    Kemal.run
  end

  def self.subscribe(serverurl : String = "")
    #every minute call self.process_changes...

  end




  get "/github" do |context|
    #TODO: changeid is given 
    #TODO: return a dict key:repo_name, value:[full_url, commit_hash, epoch]  as json
  end

  post "/github" do |context|
    body = context.params.json
    payload = body["repository"].as(Hash)
    repo_name = payload["full_name"].to_s
    # script = self.get_neph_script repo_name

    REDIS
    #incr: on gittrigger:latest
    #hset: on key=id_incr  (on gittrigger:changes), the value is [repo_name, full_url, commit_hash, epoch]  

    #TODO: the url to use to clone from, register in redis
    # pp payload["clone_url"] 
    
    puts "\n\n\n"
    CrystalTools.log "Trigger: repo_name: #{repo_name}", 2
    CrystalTools.log "Trigger: script: #{script}", 2

    unless script
      next
    end

    if @@jobs.has_key?(repo_name)
      @@jobs[repo_name] << script
    else
      @@jobs[repo_name] = Array{script}
    end

    if @@jobs[repo_name].size == 1
      spawn self.process repo_name
    end
  end
end
