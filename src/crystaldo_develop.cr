require "./crystaltools"

include CrystalTools

def changes

  gitrepo_factory = GITRepoFactory.new()

  gitrepo_factory.@repos.each do |name,r|
    puts " - #{r.name.ljust(30)} : #{r.path}"
  end

  gitrepo_factory.@repos.each do |name,r|
    if r.changes
      # TODO: implement, that we can see which repo's changed, goal is to make it easy for people to see which repo's have changes
      puts "#{r.path} has changes."
    end
  end
end

def pull1

  gitrepo_factory = GITRepoFactory.new()
  r = gitrepo_factory.get(name: "data")
  puts r.to_s

end

def jsinstall

  # installer = InstallerJumpscale.new()
  # installer.install()



end


# changes()
# pull1

jsinstall
