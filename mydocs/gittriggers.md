# Gittrigger
A Git repos manger 

#### Idea

- Server starts
- Server reads config file
- Server get all repos it need to manage from config file
- Server spawns new fiber/watcher per repo which is triggered every #n seconds (specified in repo configuration)
- when repo watcher is triggered each # n seconds it does the following
    -  pull latest code for that repo
    - check local redis and update with the latest state if new commit came along
    - state is dictionary of `repo_url`, `last_commit hash`, `last commit timestamp`, `incremental id` which is increased by one each time we update state in reis
    - If repo has new changes, scal `{repo_path}/,crystal.do` and find the starting yaml scripts there if any (configured in configuration file) and schedule them for execution
    - watcher notify slaves (configured in config file) by making http post request to their `{domain}/repos/{repo_url}` so they know this repo has changed and they pull changes and watch that repo if not watched before
- server upon starting also spawns job executor fiber that goes and execute all tasks scheduled locally
- server provide an http end poing `GET {server}/repos/{repo_url}?last_change={number}` and returns
    - `204` if no change
    - `200` and body will be new state if there's a change

#### Development


- Start server `ct gittrigger start`

#### Commands

- `start`
    - description: start gittrigger server
    - command :  `ct gittrigger start`

- `reload`
    - description: reload config file into the running local instance of gittrigger
    - command :  `ct gittrigger reload`

