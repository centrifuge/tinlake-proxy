PROXY_BIN_DIR=${PROXY_BIN_DIR:-$(cd "${0%/*}"&&pwd)}

# src env for contract deployment
source $PROXY_BIN_DIR/util.sh
source $PROXY_BIN_DIR/test/local_env.sh

# create address file and build contracts
dapp update && dapp build --extract

export PROXY_REGISTRY=$(seth send --create ./out/ProxyRegistry.bin 'ProxyRegistry()')
message Proxy Registry Address: $PROXY_REGISTRY

cd $PROXY_BIN_DIR

DEPLOYMENT_FILE=../deployments/addresses_$(seth chain).json

touch $DEPLOYMENT_FILE

addValuesToFile $DEPLOYMENT_FILE <<EOF
{
    "PROXY_REGISTRY" :"$PROXY_REGISTRY"
}
EOF
