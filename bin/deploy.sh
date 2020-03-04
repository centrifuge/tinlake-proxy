PROXY_BIN_DIR=${PROXY_BIN_DIR:-$(cd "${0%/*}"&&pwd)}
cd $PROXY_BIN_DIR
# src env for contract deployment
source $PROXY_BIN_DIR/util.sh
source $PROXY_BIN_DIR/test/local_env.sh

# create address file and build contracts

cd $PROXY_BIN_DIR/../

dapp update && dapp build --extract

cd $PROXY_BIN_DIR
# create deployment folder
mkdir $PROXY_BIN_DIR/../deployments

export PROXY_REGISTRY=$(seth send --create $PROXY_BIN_DIR/../out/ProxyRegistry.bin 'ProxyRegistry()')
message Proxy Registry Address: $PROXY_REGISTRY

DEPLOYMENT_FILE=$PROXY_BIN_DIR/../deployments/addresses_$(seth chain).json

touch $DEPLOYMENT_FILE

addValuesToFile $DEPLOYMENT_FILE <<EOF
{
    "PROXY_REGISTRY" :"$PROXY_REGISTRY"
}
EOF
