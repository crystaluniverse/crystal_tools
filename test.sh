set -ex
export DEBUG=1
crystal build src/crystaldo_develop.cr
./crystaldo_develop

