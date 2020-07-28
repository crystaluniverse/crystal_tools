# neph

> do is nothing more than neph bundled in, all credits to: https://github.com/tbrand/neph

a very nice way how to execute lots of commands in parallel

```bash
cd `ct git path -u https://github.com/crystaluniverse/crystaltools`/examples && ./sleep.sh

Neph is running (0.2.12) ||||||||||||||||||||||||||||||||||||||||||||||||||100%
main [7/7] done.   806.73ms
 - sub_job0 [3/3] done.   1.01s
     - sub_sub_job0 [1/1] done.   607.94ms
     - sub_sub_job1 [1/1] done.   807.06ms
 - sub_job1 [2/2] done.   2.02s
     - sub_sub_job2 [1/1] done.   1.01s
 - sub_job2 [1/1] done.   1.41s

Finished in 3.89s
```

or 

```bash
cd `ct git path -u https://github.com/crystaluniverse/crystaltools`/examples && ct do exec neph.yaml && echo "***DONE***"

```

see how we used the cd trick to find this dir to work on 

the logs are in .neph inside the location where you started do exec from...



## use tmux inside

- a nice trick is to use tmux inside, so you can run quite some commands in tmux if that would make sense


## use the path trick from ct git path

```bash
#get the path from home folder of threefold foundation
export MYDIR=`ct git path -n threefoldfoundation`
echo "'$MYDIR'"
```

or

```bash
#get the path from home folder of threefold foundation
export MYDIR=`ct git path -n threefoldfoundation`
echo "'$MYDIR'"
```

## more info

- [Execute command from neph](execute_command_from_neph)
- [Define dependencies between jobs](define_dependencies_between_jobs)
- [Working directory](working_directory)
- [Specify sources](specify_sources)
- [Ignoring errors](ignoring_errors)
- [Hide executing command](hide_executing_command)
- [Set a job result to env vars](set_a_job_result_to_env_vars)
- [Import other configurations](import_other_configurations)
- [Command line options](command_line_options)
- [Log locations](log_locations)
- [Log modes](log_modes)
