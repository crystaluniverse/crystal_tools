# Can I hide executing commands?

Especially under CI, you would like to hide your executing commands since some of them include some secret parameters. From version 0.1.14, you can hide them by **hide** option.
```yaml
hide_command:
  commands:
    - sleep 1
    - echo "Can you see me?"
  hide:
    true
```
The result is

![2017-09-13 22 34 17](https://user-images.githubusercontent.com/3483230/30380137-bdefdfcc-98d3-11e7-9e20-85aada462577.png)