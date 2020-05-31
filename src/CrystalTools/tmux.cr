require "redis"

module CrystalTools
  class TMUXFactory
    @@sessions = {} of String => TMUXSession
    @@_scanned = false

    def self.init
      if @@_scanned == false
        CrystalTools.log "scan", 3

        self.scan
        @@_scanned = true
      end
    end

    # get a session, will make sure it exists
    def self.session_get(name = "", restart = false, init = true)
      if init
        init()
      end
      nameL = name.downcase
      if @@sessions.has_key?(nameL)
        session = @@sessions[nameL]
        # session exists so need to restart
        if restart
          session.restart
        end
      else
        session = TMUXSession.new name: nameL
        if restart
          session.restart
        else
          if init
            session.create
          end
        end
        @@sessions[nameL] = session
      end
      session
    end

    # scan all known tmux sessions
    # build up the structure in memory
    def self.scan(reset = false)
      # CrystalTools.log "scan"
      if reset
        @@sessions = {} of String => TMUXSession
      end

      if ! Executor.exec_ok "tmux list-sessions"
        #means there is no server running
        return
      end
      
      done = Hash(String,Bool).new

      out = Executor.exec "tmux list-windows -a -F '\#{session_name}|\#{window_name}|\#{window_id}|\#{pane_active}|\#{pane_pid}|\#{pane_start_command}'"
      out.each_line do |line|
        if line.includes?("|")
          session_name, window_name, window_id, pane_active, pane_pid, pane_start_command = line.split("|", remove_empty: false)
          key = "#{session_name}-#{window_name}"
          CrystalTools.log " - found session:'#{session_name}' #{window_name} id:#{window_id} (#{pane_active},#{pane_pid},#{pane_start_command})"
          session = session_get name: session_name, init: false
          window_nameL = window_name.downcase
          if done.has_key?(key)
            raise "have duplicate window name #{key}"
          end
          # CrystalTools.log "new window: #{window_nameL}", 3
          if pane_active.strip == "1"
            active = true
          else
            active = false
          end
          if window_nameL != "notused"
            #skip windows of name notused
            window = session.window_get name: window_nameL , init: false
            window_id = window_id.gsub "@", ""
            window.id = window_id.to_i
            window.pid = pane_pid.to_i
            window.active = active
            done[key] = true
          end
        end
      end
    end

    # stop all tmux sessions
    def self.stop
      init()
      @@sessions.each_value do |session|
        session.stop
      end
      # make sure we empty the redis so we know that everything we did was in right session/window
      redis = RedisFactory.core_get
      active_session = redis.del("tmux:active_session")
      active_session = redis.del("tmux:active_window")
    end

    def self.list(session_name = "")
      init()
      @@sessions.each_value do |session|
        session.@windows.each_value do |window|
          puts " - #{session.@name}:#{window.@name}"
        end
      end
    end
  end

  # represents a tmux session
  # a tmux session has multiple windows
  class TMUXSession
    def initialize(@name : String)
      CrystalTools.log "tmuxsession: #{@name}"
      @windows = {} of String => TMUXWindow
      @name = @name.downcase

    end

    def create
      Executor.exec "tmux new-session -d -s #{@name} 'sh'", stdout: false, dolog: true, die: true, error_msg: "cannot create tmux session #{@name}"
      Executor.exec "tmux rename-window -t 0 'notused'"
    end

    # stop the tmux sessions
    def restart
      stop()
      create()
    end

    def stop
      Executor.exec "tmux kill-session -t #{@name}", stdout: true, dolog: true, die: false
    end

    def window_exist(name)
      return @windows.has_key?(name.downcase)
    end

    def window_get(name = "", init = true)
      nameL = name.downcase

      if @windows.has_key?(nameL)
        w = @windows[nameL]
        return w
      end

      if !@windows.has_key?(nameL)
        @windows[nameL] = TMUXWindow.new parent: self, name: nameL
      end

      @windows[nameL]
    end

    def execute(cmd : String, check : String)
      CrystalTools.log cmd, 3
      CrystalTools.log check, 3
      exit 0
    end

    def activate
      redis = RedisFactory.core_get
      active_session = redis.get("tmux:active_session")
      key = "#{@name}"
      if active_session != key
        # means we need to switch
        Executor.exec "tmux switch -t #{@name}", die: true, stdout: false
        redis.set("tmux:active_session", key)
      end
    end
  end

  class TMUXWindow
    include CrystalTools
    property id
    property pid
    property active

    def initialize(@parent : TMUXSession, @name : String, @id : Int32 = 0, @active = false, @pid = 0)
      @name = @name.downcase.strip
    end

    def create
      @parent.activate
      # Executor.exec "tmux new-window -t #{@parent.name}:#{@nr} -n #{@name}"
      if @active == false
        Executor.exec "tmux new-window -t #{@parent.@name} -n #{@name}"
      end
      # make sure we scan again
      TMUXFactory.scan
    end

    def restart
      stop()
      create()
    end

    # stop the tmux window (is window)
    def stop
        if @pid > 0
            Executor.exec "kill -9 #{@pid}"
        end
        @pid = 0
        @active = false
        @parent.@windows.delete @name
    end

    # look for right window/session make sure activation is done
    # means make sure the right window is active
    # need redis for this, because we want this to work over processes
    def activate
      redis = RedisFactory.core_get
      key = "#{@parent.@name}:#{@name}"
      active_session = redis.get("tmux:active_window")
      if active_session != key || ! @active || @pid == 0
        # means we need to switch
        @parent.activate
        if ! @active || @pid == 0
            create            
        end
        Executor.exec "tmux select-window -t #{@name}"
        active_session = redis.set("tmux:active_window", key)
      end
    end

    def execute(cmd : String, check : String, reset = true)
      activate
      CrystalTools.log "window:#{@name} execute:'#{cmd}'", 3
      if reset
        restart()
      end

    #   Executor.exec "tmux send-keys -t #{@parent.@name}:#{@id} '#{cmd}' Enter"
      Executor.exec "tmux send-keys -t #{@parent.@name} '#{cmd}' Enter"
      
      if check != ""
        raise "implement"
        Executor.exec "tmux"
      end

    end
  end
end
