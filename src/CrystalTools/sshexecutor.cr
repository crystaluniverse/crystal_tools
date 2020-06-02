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
end
