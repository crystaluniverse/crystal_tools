require "clim"
require "./crystaltools"
require "./gittrigger"
require "neph"

module CrystalDo


  class Cli < Clim
    include CrystalTools

    main do
      desc "Crystal Tool."
      usage "ct [sub_command] [arguments]"
      help short: "-h"

      run do |opts, args|
        puts opts.help_string # => help string.
      end

      sub "stop" do
        desc "cleanup"
        help short: "-h"
        usage "ct stop"
        run do |opts, args|
          RedisFactory.core_stop
        end
      end

      # TODO: hamdy, how can we make this more modular, want to put in different files, e.g. per topic e.g. git
      sub "git" do
        desc "work with git"
        help short: "-h"
        usage "ct git [cmd] [arguments]"
        run do |opts, args|
          puts opts.help_string
        end


        sub "path" do
          usage "ct git path [options] "
          desc "ideal to use as follows export MYDIR=`ct git path -n threefoldfoundation`"
          option "-u WORD", "--url=WORD", type: String, required: false, default: ""
          option "-e WORD", "--env=WORD", type: String, desc: "environment can be e.g. testing, production", default: ""
          option "-n WORD", "--name=WORD", type: String, desc: "Will look for destination in ~/code which has this name, if found will use it", default: ""

          run do |opts, args|
            gitrepo_factory = GITRepoFactory.new(environment: opts.env)
            thereponame = opts.name
            if opts.url != ""
              r = gitrepo_factory.get(url: opts.url)
              thereponame = r.name              
            end
            r = gitrepo_factory.get(name: thereponame)
            puts r.path
          end          
        
        end

        sub "changes" do
          help short: "-h"
          usage "ct git changes [options] "
          desc "check which repos have changes"
          option "-e WORD", "--env=WORD", type: String, desc: "environment can be e.g. testing, production.", default: ""
          argument "path", type: String, desc: "path to start from", default: ""

          run do |opts, args|
            gitrepo_factory = GITRepoFactory.new(environment: opts.env, path: args.path)
            gitrepo_factory.repos.each do |name2, r|
              if r.changes
                puts " - #{r.name.ljust(30)} : #{r.path} (CHANGED)"
              end
            end
          end
        end

        sub "code" do
          desc "open code editor (visual studio code)"
          help short: "-h"
          usage "ct code [options]"
          option "-n WORDS", "--name=WORDS", type: String, desc: "Will look for destination in ~/code which has this name, if found will use it", default: ""
          
          option "-e WORD", "--env=WORD", type: String, desc: "environment can be e.g. testing, production.", default: ""
          argument "path", type: String, desc: "path to start from", default: ""

          run do |opts, args|
            gitrepo_factory = GITRepoFactory.new(environment: opts.env, path: args.path)
            r = gitrepo_factory.get(name: opts.name)
            Executor.exec "code '#{r.@path}'"
          end
        end        

        sub "list" do
          help short: "-h"
          usage "ct git list [options] "
          desc "list repos"
          option "-e WORD", "--env=WORD", type: String, desc: "environment can be e.g. testing, production.", default: ""
          argument "path", type: String, desc: "path to start from", default: ""

          run do |opts, args|
            gitrepo_factory = GITRepoFactory.new(environment: opts.env, path: args.path)
            gitrepo_factory.repos.each do |name,r|
              puts " - #{r.name.ljust(30)} : #{r.path}"
            end        
          end
        end        


        sub "push" do
          help short: "-h"
          usage "ct git push [options] "
          desc "commit changes & push to git repository"

          option "-e WORD", "--env=WORD", type: String, desc: "environment can be e.g. testing, production.", default: ""
          option "-v", "--verbose", type: Bool, desc: "Verbose."
          option "-n WORDS", "--name=WORDS", type: String, desc: "Will look for destination in ~/code which has this name, if found will use it", default: ""
          option "-b WORDS", "--branch=WORDS", type: String, desc: "If we need to change the branch for push", default: ""
          option "-m WORDS", "--message=WORDS", type: String, required: false, desc: "message for the commit when pushing", default: ""
          option "-p", "--pull", type: Bool, desc: "If put will pull first."
          argument "path", type: String, desc: "path to start from", default: ""

          run do |opts, args|
            gitrepo_factory = GITRepoFactory.new(environment: opts.env, path: args.path)
            names = gitrepo_factory.repo_names_get(name: opts.name)
            names.each do |name2|
              # CrystalTools.log "push/commit #{name2}", 1
              r = gitrepo_factory.get(name: name2)
              if opts.branch != ""
                raise "not implemented"
              end
              if opt.pull
              puts "pull push"
                r.commit_pull_push(msg: opts.message)
              else
                if r.changes
                  r.commit(msg: opts.message)
                  r.pull()
                  r.push()
                end
              end
            end
          end
        end

        sub "pull" do
          help short: "-h"
          usage "ct git pull [options] "
          desc "pull git repository, if local changes will ask to commit if in interactive mode (default)"

          option "-d WORDS", "--dest=WORDS", type: String, default: "",
            desc: "
              destination if not specified will be
              ~code/github/$environment/$account/$repo/   
              $environment normally empty
              "

          option "-e WORD", "--env=WORD", type: String, desc: "environment can be e.g. testing, production.", default: ""
          option "-v", "--verbose", type: Bool, desc: "Verbose."
          option "-n WORD", "--name=WORD", type: String, desc: "Will look for destination in ~/code which has this name, if found will use it", default: ""
          option "-b WORD", "--branch=WORD", type: String, desc: "Branch of the repo, not needed to specify", default: ""
          option "-r WORD", "--reset=WORD", type: Bool, desc: "Will reset the local git, means overwrite whatever changes done.", default: false
          option "--depth=WORD", type: Int32, desc: "Depth of cloning. default all.", default: 0
          option "-m WORDS", "--message=WORDS", type: String, required: false, desc: "message for the commit when pushing", default: ""
          option "-u WORD", "--url=WORD", type: String, required: false, default: "",
            desc: "
              pull git repository, if local changes will ask to commit if in interactive mode (default)
              url e.g. https://github.com/at-grandpa/clim
              url e.g. git@github.com:at-grandpa/clim.git
              "
          argument "path", type: String, desc: "path to start from", default: ""

          run do |opts, args|
            gitrepo_factory = GITRepoFactory.new(environment: opts.env, path: args.path)
            thereponame = opts.name
            if opts.url != ""
              r = gitrepo_factory.get(path: opts.dest, url: opts.url, branch: opts.branch)
              thereponame = r.name
            end
            names = gitrepo_factory.repo_names_get(name: thereponame)
            names.each do |name2|
              puts "PULL: #{name2}"
              r = gitrepo_factory.get(name: name2, path: opts.dest, url: opts.url, branch: opts.branch)
              if opts.reset
                r.reset
              else
                r.pull(msg: opts.message)
              end
              # gitrepo_factory.repo_remember r
            end
          end
        end
      end

      sub "tmux" do
        help short: "-h"
        desc "work with tmux"
        usage "ct tmux [cmd] [options]"
        run do |opts, args|
          puts opts.help_string
        end

        sub "list" do
          help short: "-h"
          usage "ct tmux list [options] "
          desc "find all sessions & windows"
          option "-s WORD", "--session=WORD", type: String, desc: "Name of session", default: "default"

          run do |opts, args|
            TMUXFactory.list(session = opts.session)
          end
        end

        sub "stop" do
          help short: "-h"
          usage "ct tmux stop[options] "
          desc "stop a window or the fill session, if window not specified will kill the session"
          option "-n WORDS", "--name=WORDS", type: String, desc: "Name of session", default: ""
          option "-w WORDS", "--window=WORDS", type: String, desc: "Name of window", default: ""

          run do |opts, args|
            if opts.window == "" && opts.name == ""
              TMUXFactory.stop
              return
            end
            session = TMUXFactory.session_get(name: opts.name)
            if opts.window == ""
              session.stop
            else
              window = session.window_get(name: opts.window)
              window.stop
            end
            TMUXFactory.list
          end
        end

        sub "run" do
          help short: "-h"
          usage "ct tmux run cmd [options] [args] "
          desc "run a command in a window in a tmux session"
          option "-n WORDS", "--name=WORDS", type: String, desc: "Name of session", default: "default"
          option "-w WORDS", "--window=WORDS", type: String, desc: "Name of window", default: "default"
          option "-nr", "--noreset", type: Bool, desc: "If true then will not reset the window when it exists already", default: false
          option "-c WORDS", "--check=WORDS", type: String, desc: "Check to do, look for string in output of window.", default: ""
          argument "cmd", type: String, required: true, desc: "command to execute in the window"

          run do |opts, args|
            session = TMUXFactory.session_get(name: opts.name)
            if opts.noreset == true
              reset = false
            else
              reset = true
            end
            window = session.window_get(name: opts.window)
            window.execute cmd: args.cmd, check: opts.check, reset: reset
          end
        end
      end

      sub "sshconn" do
        help short: "-h"
        desc "work with ssh tunnels"
        usage "ct sshconn [cmd] [options]"
        run do |opts, args|
          puts opts.help_string
        end

        sub "start" do
          help short: "-h"
          usage "ct sshconn start [options]"
          desc "establish ssh tunnels connections"
          argument "config", type: String, required: true, desc: "configuration file path"

          run do |opts, args|
            sshconn = SSHConnectionTool.new args.config
            sshconn.start
          end
        end
      end

      sub "do" do
        help short: "-h"
        desc "work with task executor"
        usage "ct do [cmd] [options]"
        run do |opts, args|
          puts opts.help_string
        end

        sub "exec" do
          help short: "-h"
          usage "ct do exec [options]"
          desc "execute jobs using neph (parallel task manager)"

          option "-l WORD", "--log-mode=WORD", type: String, desc: "Log modes [NORMAL/CI/QUIET/AUTO]", default: "AUTO"
          option "-e WORD", "--exec-mode=WORD", type: String, desc: "Execution modes [parallel/sequential]", default: "parallel"
          argument "config", type: String, required: true, desc: "configuration file path"

          run do |opts, args|
            neph = NephExecuter.new config_path: args.config, log_mode: opts.log_mode, exec_mode: opts.exec_mode
            neph.exec
          end
        end

        sub "clean" do
          help short: "-h"
          usage "ct do clean"
          desc "cleaning caches"
          run do |opts, args|
            neph = NephExecuter.new
            neph.clean
          end
        end
      end

      sub "install" do
        help short: "-h"
        desc "install tools"
        usage "ct install [cmd] [options]"
        run do |opts, args|
          puts opts.help_string
        end

        sub "jumpscale" do
          help short: "-h"
          usage "ct install jumpscale [options]"
          desc "install jumpscale"

          option "-b WORD", "--branch=WORD", type: String, desc: "Log modes [NORMAL/CI/QUIET/AUTO]", default: "development"
          option "-e WORD", "--exec-mode=WORD", type: String, desc: "Execution modes [parallel/sequential]", default: "parallel"
          argument "config", type: String, required: true, desc: "configuration file path"

          run do |opts, args|
            installer = InstallerJumpscale.install()
          end
        end

      end      

      sub "gittrigger" do
        help short: "-h"
        desc "work with git trigger"
        usage "ct gittrigger [cmd] [options]"
        run do |opts, args|
          puts opts.help_string
        end

        sub "start" do
          help short: "-h"
          usage "ct gittrigger start"
          desc "start git trigger server"
          run do |opts, args|
            GitTrigger.init
            GitTrigger.start
          end
        end

        sub "reload" do
          help short: "-h"
          usage "ct gittrigger reload"
          desc "reload git trigger server"
          run do |opts, args|
            begin
              GitTrigger.init
              GitTrigger.reload
            rescue ex
              CrystalTools.log "- [GitTrigger Server] :: Configuration reloaded failure. #{ex}", 3
            end
          end
        end
      end

      sub "web" do
        desc "work with tfweb tools"
        help short: "-h"
        usage "ct git [cmd] [arguments]"
        run do |opts, args|
          puts opts.help_string
        end

        sub "start" do
          usage "ct web start [options] "
          desc "ideal to use as follows export MYDIR=`ct git path -n threefoldfoundation`"
          option "-u WORD", "--url=WORD", type: String, required: false, default: ""
          option "-e WORD", "--env=WORD", type: String, desc: "environment can be e.g. testing, production", default: ""
          option "-n WORD", "--name=WORD", type: String, desc: "Will look for destination in ~/code which has this name, if found will use it", default: ""
          option "-d", "--default", type: Bool, desc: "Default web environment."

          run do |opts, args|

            if opts.default == true

              cmd2 = "cd ~/code/github/crystaluniverse/publishingtools;tfweb -c ~/code/github/threefoldfoundation/websites/config.toml"
              session = TMUXFactory.session_get(name: "default")
              window = session.window_get(name: "tfweb")
              window.execute cmd: cmd2, check: "", reset: true
            else

              gitrepo_factory = GITRepoFactory.new(environment: opts.env)
              thereponame = opts.name
              if opts.url != ""
                r = gitrepo_factory.get(url: opts.url)
                thereponame = r.name              
              end
              r = gitrepo_factory.get(name: thereponame)
              pp r

            end
          end          
        
        end
      end

    end
  end
end

CrystalDo::Cli.start(ARGV)
