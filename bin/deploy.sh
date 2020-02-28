BIN_DIR=${BIN_DIR:-$(cd "${0%/*}"&&pwd)}

# src env for contract deployment
source $BIN_DIR/util.sh
source $BIN_DIR/test/local_env.sh

# create address file and build contracts
touch $BIN_DIR/test/addresses.json

dapp update && dapp build --extract

export PROXY_REGISTRY=$(seth send --create ./out/ProxyRegistry.bin 'ProxyRegistry()')
message Proxy Registry Address: $PROXY_REGISTRY

DEPLOYMENT_FILE=$BIN_DIR/test/addresses.json

addValuesToFile $DEPLOYMENT_FILE <<EOF
{
    "PROXY_REGISTRY" :"$PROXY_REGISTRY"
}
EOF
