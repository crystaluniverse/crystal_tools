require "ssh2"

class SSHExecutor
  property hostaddr : String = "127.0.0.1"
  property port : Int32 = 22
  property username : String = "root"

  def connect_ssh
    SSH2::Session.open(@hostaddr, @port) do |session|
      session.login_with_agent(@username)
      yield session
    end
  end

  def execute(cmd)
    connect_ssh do |session|
      session.open_session do |channel|
        channel.command(cmd)
        resp = channel.gets_to_end
        return channel.exit_status, resp
      end
    end
  end

  def scp_send_file(path)
    connect_ssh do |session|
      session.scp_send_file(path)
    end
  end

  def scp_recv_file(path)
    connect_ssh do |session|
      session.scp_recv_file(path)
    end
  end

  def read_output(channel)
    raw_data = Bytes.new(2048)
    loop do
      bytes_read = channel.read(raw_data)
      output = String.new(raw_data[0, bytes_read])
      print output
      if channel.eof?
        channel.close
        break
      end
    end
  end

  def monitor_channel(channel)
    loop do
      if channel.closed?
        return
      end
      sleep 1
    end
  end

  def shell
    connect_ssh do |session|
      session.open_session do |channel|
        # request the terminal has echo mode off
        channel.request_pty("vt100", [{SSH2::TerminalMode::ECHO, 0u32}])
        channel.shell
        spawn { read_output(channel) }
        loop do
          cmd = gets
          if !cmd
            next
          end
          cmd = cmd + "\n"
          channel.write(cmd.to_slice)

          if cmd == "exit\n"
            monitor_channel(channel)
            session.disconnect
            break
          end
        end
      end
    end
  end
end

executor = SSHExecutor.new
executor.hostaddr = "172.17.0.2"
# executor.connect_ssh do |session|
#   rc, output = executor.execute("ls /
# uptime")
#   puts "Exit status "
#   puts rc
#   puts "output"
#   puts output
# end
executor.shell
# executor.connect_ssh do |session|
#   rc, output = executor.execute("ls /")
#   puts "Exit status "
#   puts rc
#   puts "output"
#   puts output
# end
