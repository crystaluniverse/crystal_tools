module CrystalTools
  class Executor
    @@_platform : String = ""

    def self.platform
      if @@_platform == ""
        if Executor.cmd_exists_check("sw_vers")
          @@_platform = "osx"
        elsif Executor.cmd_exists_check("apt")
          @@_platform = "ubuntu"
        elsif Executor.cmd_exists_check("apk")
          @@_platform = "alpine"
        else
          raise "only ubuntu, alpine and osx supported for now"
        end
      end
      return @@_platform
    end

    def self.exec_ok(cmd)
      `#{cmd} 2> /dev/null`
       if $?.success?
           return true
       end
       false
    end

    #   # def self._exec(cmd)
    #   #   out1,in1 = IO.pipe
    #   #   out2,in2 = IO.pipe
    #   #   s = Process.new(cmd,shell: true, output: in1, error: in2)
    #   #   loop do
    #   #       pp out1.gets
    #   #       # if out1.peek
    #   #       #     pp out1.gets
    #   #       # end
    #   #       # if out2.peek
    #   #       #     pp out2.gets
    #   #       # end
    #   #       # sleep 0.001
    #   #   end
    #   # end

    def self.exec(cmd, args = nil, error_msg = "", stdout = true, dolog = true, die = true)
      iserror : Bool = false
      if dolog
        CrystalTools.log "EXEC: '#{cmd}'"
      end
      if stdout
        if args == nil
          res = `#{cmd}`
        else
          res = `#{cmd} #{args.not_nil!.join(" ")}`
        end
        res = `#{cmd} #{args}`
        iserror = !$?.success?
      else
        CrystalTools.log "get stdout", 3
        stdout = IO::Memory.new
        pp! args
        process = Process.new(cmd, args: args, shell: true, output: stdout)
        status_int = process.wait.exit_status
        if status_int == 1
          iserror = true
        end
        # stdout.flush
        # stdout.rewind
        res = stdout.to_s
        # `#{cmd} 2>&1 &>/dev/null`
        # res=""
      end

      res = res.chomp

      if !iserror
        if dolog
          CrystalTools.log "RES: '#{res}'", 1
        end
        return res
      else
        if !die
          return ""
        end
        # TODO: how can we read from the stderror
        if error_msg == ""
          CrystalTools.error "could not execute: \n#{cmd}\n**RES:**\n#{res}"
        else
          CrystalTools.error "#{error_msg}", res
        end
      end
      return res
    end

    def self.package_install(name = "",expiration_check = 3600*24*7, reset = false)
      if RedisFactory.done_check("package.install.#{name}") && reset == false
        return
      end
      if platform == "osx"
        exec "brew install #{name}"
      elsif platform == "ubuntu"
        exec "apt install #{name} -y"
      elsif platform == "alpine"
        exec "apk install #{name}"
      else
        raise "platform not supported, only support osx, ubuntu & alpine"
      end
      RedisFactory.done_set("package.install.#{name}", expiration: expiration_check)
    end

    def self.package_upgrade(expiration_check = 3600*24*7, reset = false)
      if RedisFactory.done_check("package.upgradeall") && reset == false
        return
      end
      if platform == "osx"
        exec "brew update"
        exec "brew upgrade"
      elsif platform == "ubuntu"
        exec "apt update"
        exec "apt upgrade -y"
      elsif platform == "alpine"
        CrystalTools.error "not implemented"
      else
        raise "platform not supported, only support osx, ubuntu & alpine"
      end
      RedisFactory.done_set("package.upgradeall", expiration: expiration_check)
    end    

    def self.cmd_exists_check(cmd)
      `which #{cmd} 2>&1 > /dev/null`
      if !$?.success?
        return false
        # CrystalTools.error "#{cmd} not installed, cannot continue."
      end
      return true
    end

    macro exec2(cmd, error_msg = "", stdout = false)
      {% if stdout == true %}
        `{{cmd}}`
      {% else %}
      `{{cmd}} 2>&1 &>/dev/null`
      {% end %}
      if !$?.success?
        {% if error_msg == "" %}
        CrystalTools.error "could not execute: {{cmd}}"
        {% else %}
        CrystalTools.error "{{error_msg}}"
        {% end %}
      end    
    end
  end
end
