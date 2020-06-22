# How can I ignore the error of the jobs?
You can proceed the execution of the series of the jobs even if some jobs in it fail.

Here is an example.
```yaml
main:
  commands:
    - echo "come here!"
  depends_on:
    omg_job

omg_job:
  commands:
    - omg
  ignore_error:
    true
```
Here, `omg_job` will be failed since there is no valid command named `omg`. But main job will be triggered since `neph` will ignore the error of the `omg_job`.