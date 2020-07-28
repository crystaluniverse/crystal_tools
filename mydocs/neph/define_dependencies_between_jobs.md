# I want to define dependencies between jobs
You can define dependencies between jobs.

Edit your `neph.yml` like this
```yaml
main:
  commands:
    - echo "This is a main job!"
  depends_on:
    sub_job

sub_job:
  commands:
    - echo "This is a sub job!"
```
Here, `main` job depends on `sub_job`. So `sub_job` is triggered before the `main` job's execution.

You can define multiple/nested dependencies.
```yaml
main:
  depends_on:
    - sub_job0
    - sub_job1

sub_job:
  depends_on:
    sub_sub_job

sub_job1:
  command:
    echo "World!"

sub_sub_job:
  command:
    echo "Hello"
```