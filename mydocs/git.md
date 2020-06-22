# git tools

Aim is to have a super easy tool for anyone to manipulate git repositories

## generic

```bash
ct git --help

  work with git

  Usage:

    ct git [cmd] [arguments]

  Options:

    -h, --help                       Show this help.

  Sub Commands:

    changes   check which repos have changes
    code      open code editor (visual studio code)
    list      list repos
    push      commit changes & push to git repository
    pull      pull git repository, if local changes will ask to commit if in interactive mode (default)
```

- on each command you can use an argument which is the path to start from 
  - can be empty, then it will be ~/code
  - when ```.``` it will be the current dir you are in
  - or you can define a path to start from
  - this is useful for any command to specify on which repo's to work
- on each command you can use an environment argument (-e), this is to specify a specific env like 'testing', most of you will not need this
  - this will change ~/code to ~/code_$env   
  - can be ignored by most users

## checkout a repo (clone=pull)

- How to get started with a repo?
- In git we call getting a repo to clone or pull the repo from git.

```bash
 ct git pull -h

  pull git repository, if local changes will ask to commit if in interactive mode (default)

  Usage:

    ct git pull [options]

  Options:

    -d WORDS, --dest=WORDS
              destination if not specified will be
              ~code/github/$environment/$account/$repo/
              $environment normally empty

    -e WORD, --env=WORD              environment can be e.g. testing, production, is a prefix to github dir in code.
    -v, --verbose                    Verbose
    -n WORD, --name=WORD             Will look for destination in ~/code which has this name, if found will use it
    -b WORD, --branch=WORD           Branch of the repo, not needed to specify
    -r WORD, --reset=WORD            Will reset the local git, means overwrite whatever changes done.
    
    --depth=WORD                     Depth of cloning. default all.

    -m WORDS, --message=WORDS        message for the commit when pushing.
    
    -u WORD, --url=WORD
              pull git repository, if local changes will ask to commit if in interactive mode (default)
              url e.g. https://github.com/at-grandpa/clim
              url e.g. git@github.com:at-grandpa/clim.git

  Arguments:
    path      OPTIONAL: path to start from, e.g. used when you want to pull all repos in a certain location (or on full code path)

```


```bash
#pull the home repo
ct git pull -u https://github.com/threefoldtech/home
```

result

```bash
ct git pull -u https://github.com/threefoldtech/home
Cloning into 'home'...
remote: Enumerating objects: 10, done.
remote: Counting objects: 100% (10/10), done.
remote: Compressing objects: 100% (10/10), done.
remote: Total 550 (delta 3), reused 0 (delta 0), pack-reused 540
Receiving objects: 100% (550/550), 519.79 KiB | 1.25 MiB/s, done.
Resolving deltas: 100% (292/292), done.
 - crystaltools              :  - Pull /Users/despiegk/code/github/threefoldtech/home
PULL: home
 - crystaltools              :  - Pull /Users/despiegk/code/github/threefoldtech/home
```

can also do
```bash
#pull the home repo, this time use other url (based on git)
ct git pull -u git@github.com:threefoldtech/home.git
```

you can see where the repo is checked out

### To do a pull of more repositories

will check out all repo's in code dir and when changes found will ask for a commit message

```bash
ct git pull
```

```bash
#will do same but starting from existing repo (the one you are on in your console)
ct git pull .
```



## list

## changes

```bash
ct git changes --help

  check which repos have changes

  Usage:

    ct git changes [options]

  Options:

    -e WORD, --env=WORD              environment can be e.g. testing, production, is a prefix to github dir in code. [type:String] [default:""]
    -h, --help                       Show this help.

  Arguments:
    path      OPTIONAL: path to start from while doing the search
```
#go to threefold foundation repo
cd ~/code/github/threefoldfoundation
#will list changes in that location
ct git changes .
#list all changes (all in ~/code)
ct git changes

```bash

```