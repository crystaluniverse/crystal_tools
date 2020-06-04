require "option_parser"
require "file_utils"
require "colorize"
require "neph"

module CrystalTools
    class NephExecuter
        CONFIG_PATH = "neph.yaml"
        @job_names : Array(String) = ["main"]

        def initialize (
            @config_path : String = "neph.yaml",
            @log_mode : String = "AUTO",
            @exec_mode : String = "parallel"
        )

            ready_dir

            if @log_mode == "AUTO"
                if STDOUT.tty?
                    @log_mode = "NORMAL"
                else
                    @log_mode = "CI"
                end
            end
        end

        def clean
            FileUtils.rm_rf(NEPH_DIR) if Dir.exists?(NEPH_DIR)
        end

        def exec
            main_job : Job = if @job_names.size == 1
                parse_yaml(@job_names[0], @config_path)
            else
                sub_jobs = @job_names.map { |j| parse_yaml(j, @config_path) }
                job_name = sub_jobs.map { |j| j.name }.join(", ")
                job = Job.new(job_name, [] of String, [] of String, [] of String, nil)
                sub_jobs.each do |s|
                    job.add_sub_job(s, nil)
                end
                job
            end
            job_executor = JobExecutor.new(main_job, @exec_mode, @log_mode)
            job_executor.exec
        end

        include Neph
    end
end
