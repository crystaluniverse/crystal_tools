# Can we import other configuration files?

Use `import` feature. Let me assume you already have a `awesome.yml` like this.
```yaml
awesome_job:
  commands:
    - echo "This is a really awesome!!"
```

And import it into your neph.yml.
```yaml
import:
  - awesome.yml

main:
  commands:
    - echo "Executed awesome job..."
  depends_on:
    awesome_job
```