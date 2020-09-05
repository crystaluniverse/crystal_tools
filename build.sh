set +ex
shards build --error-trace
cp bin/ct /usr/local/bin/ct
mkdir -p ~/Downloads/
cp bin/ct ~/Downloads/ct

