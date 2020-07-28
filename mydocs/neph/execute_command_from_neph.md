# How do we start `neph`?
Put a `neph.yml` onto root of your project.

Define `main` job that is executed by default.
```yaml
main:
  commands:
    - echo "Hello from neph!"
```

After that, execute.
```
$ neph
```

You can get the result at `.neph/main/log/log.out`.

You can define multiple commands like this
```yaml
main:
  commands:
    - echo "This is a first line!"
    - echo "This is a second line!"
```