# What options can we use in neph?

Here is a result of `neph --help`.
```
Basic usage: neph [options] [job_name]
    -y CONFIG, --yaml=CONFIG         Specify a location of neph.yaml (Default is neph.yaml)
    -m MODE, --mode=MODE             Log modes [NORMAL/CI/QUIET/AUTO] (Default is AUTO)
    -v, --version                    Show the version
    -h, --help                       Show this help
    -c, --clean                      Cleaning caches
    -s, --seq                        Execute jobs sequentially. (Default is parallel.)
Recent incompatible changes:
    - '.yml' extension changed to '.yaml'
    - 'uninstall' action removed, because it is the job of the distro package manager
    - 'clean' action moved to '--clean'
    - '-j|--job' option removed
```

- The `uninstall` and `clean` actions were removed in `v0.1.18`.  
  You can uninstall it with your distro package manager, or manually.  
  You can clean caches with `-c, --clean`.
- The `-j, --job` option were also removed in `v0.1.18`.  
  You can specify the job name without an option: `neph [job name]`.