# Gittrigger

## Development


- Start server with (webhook Secret) `ct gittrigger start secret bd18973d-8e28-438d-8fbc-2dbb279c8fce`
- run `ngrok http 8080` and get the URL
- configure a testing repo on your github account, add a new webhook with `secret=bd18973d-8e28-438d-8fbc-2dbb279c8fce` and `url={ngrok_url/github}`
- commit a change to repo `echo "soso" >> README.md && git add . && git commit -m "commit" && git push`
- get last changes from server using `GET 127.0.0.1:8080/github?repo_name={githubusername}/{reponame}&last_change=2`
    - `404` means reponame is wrong
    - `204` means no changes
    - `200` means check json body for changes i.e 
        ```
        {"url":"https://github.com/Hamdy/test","last_commit":"e1191e7c91456af75ecc3321f1df5b9cc9e59f8f","timestamp":"1592917149","id":"3"}
        ```
