require "kemal"
require "json"
require "http/client"
require "./crystaltools"

module GitTrigger
  @@jobs = {} of String => Array(String)

  def self.get_neph_script(repo_name : String)
    response = HTTP::Client.get "https://raw.githubusercontent.com/#{repo_name}/master/.neph.yml"
    if response.status_code == 200
      response.body
    end
  end

  def self.run(repo_name : String, script : String)
    path = File.expand_path(repo_name.sub("/", "-"))
    File.write(path, script)
    begin
      neph = CrystalTools::NephExecuter.new path
      neph.exec
    ensure
      File.delete(path)
    end
  end

  def self.process(repo_name : String)
    until @@jobs[repo_name].size == 0
      self.run(repo_name, @@jobs[repo_name].first)
      @@jobs[repo_name].shift
    end
  end

  def self.start
    Kemal.config.port = 8080
    Kemal.run
  end

  post "/github" do |context|
    body = context.params.json
    payload = body["repository"].as(Hash)
    repo_name = payload["full_name"].to_s
    script = self.get_neph_script repo_name

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
