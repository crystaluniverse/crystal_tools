# Gittrigger
A Git repos manger 

#### Idea

- Server starts
- Server reads config file
- Server get all repos it need to manage from config file
- Server spawns new fiber/watcher per repo which is triggered every #n seconds (specified in repo configuration)
- when repo watcher is triggered it pulls, check local redis if it has same state of the repp and update if needed
- If repo state is updated, it means there're new changes, server reads the `.crystal.do` watcher reads `main.yaml` neph file for that repo and execute locally in another fiber
- subscribers/slaves are notified that there're new changes, so they can pull this repo and update their local state

#### Development


- Start server `ct gittrigger start`
- run ngrok if needed `ngrok http 8080` and get the URL

#### subcommands
- `subscibe`
    - description: subscribe a local instnce to remote server 
    - command :  `ct gittrigger subscribe {remote_url}`
    - mechanism: gets the server ID from `gittrigger.toml` and send it to the remote machine. remote machine config file will be updated/re-rewritten with the new subscriber
    - testing: `ct gittrigger subscribe "http://127.0.0.1:8000"` this is to register the local isntance as slave in itself. (only for testing)

- `reload`
    - description: reload config file into the running local instance of gittrigger
    - command :  `ct gittrigger reload`

