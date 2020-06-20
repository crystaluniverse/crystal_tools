set -ex
export DEBUG=0
crystal build src/crystaldo_develop.cr
./crystaldo_develop

