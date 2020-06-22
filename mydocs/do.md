# do

a very nice way how to execute lots of commands in parallel

```bash
export MYDIR=`ct git path -u https://github.com/crystaluniverse/crystaltools` && cd $MYDIR/examples && ./do.sh

Neph is running (0.2.12) ||||||||||||||||||||||||||||||||||||||||||||||||||100%
main [7/7] done.   806.73ms
 - sub_job0 [3/3] done.   1.01s
     - sub_sub_job0 [1/1] done.   607.94ms
     - sub_sub_job1 [1/1] done.   807.06ms
 - sub_job1 [2/2] done.   2.02s
     - sub_sub_job2 [1/1] done.   1.01s
 - sub_job2 [1/1] done.   1.41s

Finished in 3.89s
```



## use tmux inside

- a nice trick is to use tmux inside, so you can run quite some commands in tmux if that would make sense


## use the path trick from ct git path

```bash
#get the path from home folder of threefold foundation
export MYDIR=`ct git path -n threefoldfoundation`
echo "'$MYDIR'"
```

or

```bash
#get the path from home folder of threefold foundation
export MYDIR=`ct git path -n threefoldfoundation`
echo "'$MYDIR'"
```

