# src env for contract deployment
source ./bin/util.sh
source ./bin/test/local_env.sh


# create address file and build contracts
touch ./bin/test/addresses.json

dapp update && dapp build --extract

export PROXY_REGISTRY=$(seth send --create ./out/ProxyRegistry.bin 'ProxyRegistry()')
message Proxy Registry Address: $PROXY_REGISTRY

DEPLOYMENT_FILE=./bin/test/addresses.json

addValuesToFile $DEPLOYMENT_FILE <<EOF
{
    "PROXY_REGISTRY" :"$PROXY_REGISTRY"
}
EOF
