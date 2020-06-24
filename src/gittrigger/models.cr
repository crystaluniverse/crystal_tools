class RepoConfig
  property name : String = ""
  property url : String = ""
  property pull_interval : Int64 = 300_i64
end

class GitTriggerConfig
  property slaves : Array(String) = Array(String).new
  property port : Int64 = 8080_i64
  property repos : Array(RepoConfig) = Array(RepoConfig).new
end