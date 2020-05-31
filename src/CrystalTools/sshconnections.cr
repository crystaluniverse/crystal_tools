require "toml"
require "colorize"

module CrystalTools
  class SSHConnection
    property name : String
    property ipaddr : String
    property user : String
    property localport : Int64
    property remoteport : Int64

    def initialize(
      @name,
      @ipaddr,
      @user = "root",
      @localport = 3000,
      @remoteport = 3000
    )
    end

    private def startupcmd
      "ssh -o StrictHostKeyChecking=no -R #{@localport}:127.0.0.1:#{@remoteport} -N #{@user}@#{@ipaddr}"
    end

    private def check_tcp_conn
      `nc -z #{@ipaddr} #{@localport}`
      $?.success?
    end

    private def check_ssh_conn
      `nc -z #{@ipaddr} 22`
      $?.success?
    end

    private def pid
      `pgrep --exact --full "#{startupcmd}"`.split
    end

    def is_ok
      check_tcp_conn && check_ssh_conn
    end

    def start
      kill if pid
      `#{startupcmd}`
    end

    def kill
      pid.each do |pid|
        `kill -9 #{pid}`
      end
    end

    def restart
      kill
      start
    end
  end

  class SSHConnectionTool
    property configpath : Path
    property connections : Hash(String, SSHConnection)

    def initialize(configpath : String)
      @configpath = Path[configpath].expand(home: true)
      @connections = {} of String => SSHConnection
      @channel = Channel(Nil).new

      config = readconfig()
      config["sshconnections"].as(Array).each do |connection|
        connection = connection.as(Hash)
        name = connection["name"].as(String)
        @connections[name] = SSHConnection.new(
          name: name,
          ipaddr: connection["ipaddr"].as(String),
          user: connection["user"].as(String),
          localport: connection["localport"].as(Int64),
          remoteport: connection["remoteport"].as(Int64)
        )
      end
    end

    def print_success(msg)
      puts msg.colorize.green
    end

    def print_error(msg)
      puts msg.colorize.red
    end

    private def readconfig
      TOML.parse_file(@configpath)
    rescue File::NotFoundError
      print_error "Configuration file not found"
      exit 1
    rescue TOML::ParseException
      print_error "Invalid configuration"
      exit 1
    end

    def get(
      name,
      ipaddr : String = "",
      user : String = "root",
      localport : Int64 = 3000,
      remoteport : Int64 = 3000
    )
      unless @connections.includes? name
        @connections[name] = SSHConnection.new(name, ipaddr, user, localport, remoteport)
      end
      @connections[name]
    end

    def start
      @connections.each do |name, connection|
        spawn connection.start
        puts "Connection #{name} is started"
      end
      spawn monitor
      @channel.receive
    end

    def monitor
      loop do
        sleep 3.seconds
        @connections.each do |name, connection|
          if connection.is_ok
            print_success "Connection #{connection.name} is ok"
          else
            spawn connection.restart
            print_error "Connection #{connection.name} is restarted"
          end
        end
      end
    end
  end
end
