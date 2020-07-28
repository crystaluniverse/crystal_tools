# Can we use the result of the job?
You can set a job result to environment variables that can be used in the next job.

See this example.
```yaml
main:
  commands:
    - echo "The result is $RESULT"
  depends_on:
    -
      job: ruby_job
      env: RESULT

ruby_job:
  commands:
    - ruby -e 'puts 1 + 5'
```
The result of `ruby_job` is '6'. The result is set to `$RESULT` and the result of `main` job is "This result is 6".