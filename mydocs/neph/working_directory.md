# I want to change a directory for each job
You can set working directory by `dir`.

Let us assume a simple project structure
```
-/
-/src
-/src/main.c
```

Edit your `neph.yml` like this
```yaml
main:
  commands:
    - echo "Where am I?"
    - pwd
  dir:
    src
```
The result of pwd is `path_to_the_project/src`, you can confirm the result at `.neph/main/log/log.out`.