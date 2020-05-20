module CrystalTools

  class Executor
    # include CrystalTools

    def self.exec_ok(cmd)
      `#{cmd} 2>&1 &>/dev/null`
      if !$?.success?
        false
      end
      true    
    end

    # def self._exec(cmd)
    #   out1,in1 = IO.pipe
    #   out2,in2 = IO.pipe
    #   s = Process.new(cmd,shell: true, output: in1, error: in2)      
    #   loop do
    #       pp out1.gets
    #       # if out1.peek
    #       #     pp out1.gets
    #       # end
    #       # if out2.peek
    #       #     pp out2.gets
    #       # end
    #       # sleep 0.001
    #   end
    # end
      

    def self.exec(cmd, error_msg="", stdout=true)
      if stdout
        res = `#{cmd}`
      else
        `#{cmd} 2>&1 &>/dev/null`
        res=""
      end
      if $?.success?
        return res.chomp  
      else
        #TODO: how can we read from the stderror
        if error_msg == ""
          error "could not execute: #{cmd}\n#{res}"
        else
          error "#{error_msg}",res
        end
      end    
      res
    end    

  end

  macro cmd_exists_check(cmd)
    {{ debug }}
    pp "Class is: " + {{ @type.stringify }}
    pp {{@type}}
    `which {{cmd}} 2>&1 > /dev/null`
    if !$?.success?
      error "{{cmd}} not installed, cannot continue."
    end
  end

  macro exec2(cmd, error_msg="", stdout=false)
    {% if stdout == true %}
    `{{cmd}}`
    {% else %}
    `{{cmd}} 2>&1 &>/dev/null`
    {% end %}
    if !$?.success?
      {% if error_msg == "" %}
      error "could not execute: {{cmd}}"
      {% else %}
      error "{{error_msg}}"
      {% end %}
    end    
  end





end

