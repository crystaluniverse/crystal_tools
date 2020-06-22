# tmux

tmux is a process manager, normally quite difficult to use, we made ct as a easier to use front end for it.


```bash
ct tmux -h

  work with tmux

  Usage:

    ct tmux [cmd] [options]

  Options:

    -h, --help                       Show this help.

  Sub Commands:

    list   find all sessions & windows
    stop   stop a window or the fill session, if window not specified will kill the session
    run    run a command in a window in a tmux session
```

## run

```bash
ct tmux run -h

  run a command in a window in a tmux session

  Usage:

    ct tmux run cmd [options] [args]

  Options:

    -n , --name=           Name of session 
    -w , --window=         Name of window 
    -r, --reset            Kill the window first (default true)
    -c , --check=          Check to do, look for string in output of window.

  Arguments:

    cmd      command to execute in the window 

```

```bash
#will run cmd mc in session & window called default
ct tmux run 'mc'

#will run cmd mc in session & window called default
ct tmux run 'mc'

#will run cmd mc in session called test, the window is called 'mc'
ct tmux run 'mc' -n test -w mc


```

## stop

```bash
ct tmux stop -h

  stop a window or the fill session, if window not specified will kill the session

  Usage:

    ct tmux stop [options]

  Options:

    -n WORDS, --name=WORDS           Name of session [type:String] [default:""]
    -w WORDS, --window=WORDS         Name of window [type:String] [default:""]
```

> if not window or session specified, will kill all processes

## list

```bash
ct tmux list
```