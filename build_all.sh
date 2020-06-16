set +ex
crystal docs --output=./docs/ct
shards build
cp bin/ct /usr/local/bin/ct
mkdir -p ~/Downloads/
cp bin/ct ~/Downloads/ct

