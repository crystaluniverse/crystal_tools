# I want to skip the job if there is no update.
You can specify source files of the job. If the sources haven't been updated, the job will not be triggered. The feature is inspired by `make` command.

Here is an example.
```yaml
main:
  commands:
    - gcc -o bin/run src/run.c
  src:
    src/run.c
```
If the src/run.c hasn't been updated, `gcc` will be skipped.