# Where is a output of stdout and stderr?
`neph` doesn't print stdout and stderr for each job. The results are located at `.neph/[job_name]/log/log.[out/err]`

# Stacktrace
If a job command is failed, `neph` print a stdout and stderr as a stacktrace.