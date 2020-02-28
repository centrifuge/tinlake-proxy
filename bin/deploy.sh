BIN_DIR=${BIN_DIR:-$(cd "${1%/*}"&&pwd)}

# src env for contract deployment
source $BIN_DIR/bin/util.sh
source $BIN_DIR/bin/test/local_env.sh

# create address file and build contracts
touch $BIN_DIR/bin/test/addresses.json

dapp update && dapp build --extract

export PROXY_REGISTRY=$(seth send --create ./out/ProxyRegistry.bin 'ProxyRegistry()')
message Proxy Registry Address: $PROXY_REGISTRY

DEPLOYMENT_FILE=$BIN_DIR/bin/test/addresses.json

addValuesToFile $DEPLOYMENT_FILE <<EOF
{
    "PROXY_REGISTRY" :"$PROXY_REGISTRY"
}
EOF
