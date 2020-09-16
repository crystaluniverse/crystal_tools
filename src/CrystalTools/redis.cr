require "redis"
require "msgpack"

module CrystalTools
  class RedisClient < Redis::PooledClient
    # ## create stored procedure from path
    #
    # :param path: the path where the stored procedure exist
    # :type path_or_content: str which is the lua content or the path
    # :raises Exception: when we can not find the stored procedure on the path
    #
    # will return the sha
    #
    # to use the stored procedure do
    #
    # redisclient.evalsha(sha,3,"a","b","c")  3 is for nr of keys, then the args
    #
    # the stored procedure can be found in hset storedprocedures:$name has inside a json with
    #
    # is json encoded dict
    #  - script: ...
    #  - sha: ...
    #  - nrkeys: ...
    #
    # there is also storedprocedures:sha -> sha without having to decode json
    # tips on lua in redis:
    # https://redis.io/commands/eval
    def storedprocedure_register(name : String, nrkeys : Int = 0, path_or_content : String = "")
      # TODO: convert to crystal
      # if "\n" not in path_or_content:
      #     f = open(path_or_content, "r")
      #     lua = f.read()
      #     path = path_or_content
      # else:
      #     lua = path_or_content
      #     path = ""

      # script = self.register_script(lua)

      # dd = {}
      # dd["sha"] = script.sha
      # dd["script"] = lua
      # dd["nrkeys"] = nrkeys
      # dd["path"] = path

      # data = json.dumps(dd)

      # self.hset("storedprocedures:data", name, data)
      # self.hset("storedprocedures:sha", name, script.sha)

      # self._storedprocedures_to_sha = {}

      # return script
    end

    def storedprocedure_delete(name : String)
      # TODO: convert to crystal
      # self.hdel("storedprocedures:data", name)
      # self.hdel("storedprocedures:sha", name)
      # self._storedprocedures_to_sha = {}
    end

    # execute redis command using the command line of redis
    def redis_cmd_execute(command : String, debug = False, debugsync = False, keys = nil, args = nil)
      # TODO: convert to crystal
      # if not keys:
      #     keys = []
      # if not args:
      #     args = []
      # rediscmd = self._redis_cli_path
      # if debug:
      #     rediscmd += " --ldb"
      # elif debugsync:
      #     rediscmd += " --ldb-sync-mode"
      # rediscmd += " --%s" % command
      # for key in keys:
      #     rediscmd += " %s" % key
      # if len(args) > 0:
      #     rediscmd += " , "
      #     for arg in args:
      #         rediscmd += " %s" % arg
      # # print(rediscmd)
      # _, out, _ = Tools.execute(rediscmd, interactive=True)
      # return out

      #     def _sp_data(self, name):
      #         if name not in self._storedprocedures_to_sha:
      #             data = self.hget("storedprocedures:data", name)
      #             if not data:
      #                 raise Tools.exceptions.Base("could not find: '%s:%s' in redis" % (("storedprocedures:data", name)))
      #             data2 = json.loads(data)
      #             self._storedprocedures_to_sha[name] = data2
      #         return self._storedprocedures_to_sha[name]
    end

    # TODO: convert
    # def storedprocedure_execute(self, name, *args):
    #     """

    #     :param name:
    #     :param args:
    #     :return:
    #     """

    #     data = self._sp_data(name)
    #     sha = data["sha"]  # .encode()
    #     assert isinstance(sha, (str))
    #     # assert isinstance(sha, (bytes, bytearray))
    #     # Tools.shell()
    #     return self.evalsha(sha, data["nrkeys"], *args)
    #     # self.eval(data["script"],data["nrkeys"],*args)
    #     # return self.execute_command("EVALSHA",sha,data["nrkeys"],*args)

    # TODO: convert
    # def storedprocedure_debug(self, name, *args):
    #     """
    #     to see how to use the debugger see https://redis.io/topics/ldb

    #     to break put: redis.breakpoint() inside your lua code
    #     to continue: do 'c'

    #     :param name: name of the sp to execute
    #     :param args: args to it
    #     :return:
    #     """
    #     data = self._sp_data(name)
    #     path = data["path"]
    #     if path == "":
    #         from pudb import set_trace

    #         set_trace()

    #     nrkeys = data["nrkeys"]
    #     args2 = args[nrkeys:]
    #     keys = args[:nrkeys]

    #     out = self.redis_cmd_execute("eval %s" % path, debug=True, keys=keys, args=args2)

    #     return out

  end

  # how to use
  #   RedisFactory.core_get
  class RedisFactory
    # property sessions : Hash(String, CrystalTools::RedisClient)
    @@sessions = {} of String => RedisClient

    # get a session, will make sure it exists
    def self.client_get(name = "", host = "localhost", port = 6379, unixsocket : String? = nil, password : String? = nil, pool_size : Int32 = 20)
      nameL = name.downcase
      if !@@sessions.has_key?(nameL)
        if unixsocket == nil
          unixsocket = "/tmp/redis.sock"
        end
        # CrystalTools.log unixsocket
        # @@sessions[nameL] = RedisClient.new(host: host, port: port, unixsocket: unixsocket, password: password)
        CrystalTools.log "INIT REDIS CLIENT"
        @@sessions[nameL] = RedisClient.new(host: host, unixsocket: unixsocket, password: password, pool_size: pool_size)
      end
      @@sessions[nameL]
    end

    def self.serialize(data : Object |Int32 | String | Bool | Bytes | Nil)
      if typeof(data) == Class
        return data.to_msgpack
      end
      return data
    end

    #this is to remember what has already been done, normally we don't keep a value but can be useful to not have to redo a cmd
    #expiration default is not set
    def self.done_set(key = "", expiration : (Nil | Int32) = nil, val : ( Int32 | String | Bool | Nil) = nil)
      cl = self.core_get
      cl.set("done.#{key}", val, ex=expiration)
    end

    #check if there a value and that it needs to be 1 (useful if no value)
    def self.done_check(key = "")
      cl = self.core_get
      return cl.exists("done.#{key}") == 1
    end

    def self.done_get(key = "")
      cl = self.core_get
      data = cl.get("done.#{key}")
      if data == ""
        data = nil
      end
      return data
    end

    #if key is "" then will reset all
    def self.done_reset(key = "", prefix = "")
      cl = self.core_get
      if key == ""
        if prefix == ""
          ks=cl.keys("done.*")
        else
          ks=cl.keys("done.#{prefix}*")
        end
        ks.each do |key|
          cl.del(key.to_s)
        end
      else
        cl.del("done.#{key}")
      end
    end

    def self.done_list(prefix = "")
      cl = self.core_get
      r = [] of String
      if prefix == ""
        ks=cl.keys("done.*")
      else
        ks=cl.keys("done.#{prefix}*")
      end
      ks.each do |key|
        r << key.to_s
      end
      return r
    end    

    #reset the redis core db, remove all
    def self.core_reset
      cl = self.core_get
      cl.flushall  
    end

    # start redis server if not done yet
    def self.core_get

      if !@@sessions.has_key?("core")
        if !Executor.cmd_exists_check "redis-cli"
          if Executor.platform == "osx"
            Executor.exec("brew unlink redis", die = false, stdout: false)
            Executor.exec("brew install redis", stdout: false)
            Executor.exec("brew link redis", stdout: false)
          else
            Executor.package_install "redis-server"
            Executor.exec("sudo service redis-server stop") # stop because it will be started using sockets later
            sleep 0.3
          end
        end

        if !core_exists
          CrystalTools.log "Redis -core does not exist yet", 3
	        CrystalTools.log "Redis -core stop any running redis instances", 2 
          # Killing & Resrarting redis with unix socket support
          Executor.exec("sudo service redis-server stop")
	        CrystalTools.log "Redis -core start redis again with unix socket support", 2 
          Executor.exec "redis-server --unixsocket /tmp/redis.sock --port 6379 --maxmemory 10000000 --daemonize yes"
          sleep 0.3
        end
      end

      client_get "core"
    end

    def self.get_existing_core
      if self.core_exists
        self.core_get
      else
        nil
      end
    end

    def self.core_exists
      begin
        cl = client_get()
        cl.ping()
      rescue
        return false
      end
      return true
    end

    def self.core_stop
      CrystalTools.log "stop redis core", 3
      if self.core_exists
        cl = core_get
        cl.close
        @@sessions.delete("core")
      end
      Executor.exec "redis-cli -s /tmp/redis.sock shutdown", die: false
      Executor.exec "rm -f /tmp/redis.sock", die: false
    end
  end
end

# TODO: implement, is there a redis queue in the redis client in crystal?, id not implement this one
# class RedisQueue:
#     def __init__(self, redis, key):
#         self._db_ = redis
#         self.key = key

#     def qsize(self):
#         """Return the approximate size of the queue.

#         :return: approximate size of queue
#         :rtype: int
#         """
#         return self._db_.llen(self.key)

#     @property
#     def empty(self):
#         """Return True if the queue is empty, False otherwise."""
#         return self.qsize() == 0

#     def reset(self):
#         """
#         make empty
#         :return:
#         """
#         while self.empty is False:
#             if self.get_nowait() is None:
#                 self.empty = True

#     def put(self, item):
#         """Put item into the queue."""
#         self._db_.rpush(self.key, item)

#     def get(self, timeout=20):
#         """Remove and return an item from the queue."""
#         if timeout > 0:
#             item = self._db_.blpop(self.key, timeout=timeout)
#             if item:
#                 item = item[1]
#         else:
#             item = self._db_.lpop(self.key)
#         return item

#     def fetch(self, block=True, timeout=None):
#         """Return an item from the queue without removing"""
#         if block:
#             # TODO: doesn not seem right
#             item = self._db_.brpoplpush(self.key, self.key, timeout)
#         else:
#             item = self._db_.lindex(self.key, 0)
#         return item

#     def set_expire(self, time):
#         self._db_.expire(self.key, time)

#     def get_nowait(self):
#         """Equivalent to get(False)."""
#         return self.get(False)
