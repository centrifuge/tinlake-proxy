// proxy.sol -- proxy contract for delegate calls
// Copyright (C) 2019 Centrifuge

// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

pragma solidity >=0.5.3;

import { Title, TitleOwned, TitleLike } from "tinlake-title/title.sol";

contract RegistryLike {
    function cacheRead(bytes memory _code) public view returns (address);
    function cacheWrite(bytes memory _code) public returns (address target);
}

// Proxy is a proxy contract that is controlled by a Title NFT (see tinlake-title)
// The proxy execute methods are copied from ds-proxy/src/proxy.sol:DSProxy
// (see https://github.com/dapphub/ds-proxy)
contract Proxy is TitleOwned {
    uint public         accessToken;
    RegistryLike public registry;

    bool initialized;

    constructor() TitleOwned(msg.sender) public {
        registry = RegistryLike(msg.sender);
    }

    function init(uint accessToken_) public {
        require(initialized == false);
        accessToken = accessToken_;
        initialized = true;
    }

    function() external payable {
    }

    function execute(address _target, bytes memory _data)
    public
    payable
    owner(accessToken)
    returns (bytes memory response)
    {
        require(_target != address(0), "tinlake/proxy-target-address-required");

        // call contract in current context
        assembly {
            let succeeded := delegatecall(sub(gas, 5000), _target, add(_data, 0x20), mload(_data), 0, 0)
            let size := returndatasize

            response := mload(0x40)
            mstore(0x40, add(response, and(add(add(size, 0x20), 0x1f), not(0x1f))))
            mstore(response, size)
            returndatacopy(add(response, 0x20), 0, size)

            switch iszero(succeeded)
            case 1 {
            // throw if delegatecall failed
                revert(add(response, 0x20), size)
            }
        }
    }

    function executeByteCode(bytes memory _code, bytes memory _data)
    public
    payable
    owner(accessToken)
    returns (address target, bytes memory response)
    {
        target = registry.cacheRead(_code);
        if (target == address(0)) {
            // deploy contract & store its address in cache
            target = registry.cacheWrite(_code);
        }

        response = execute(target, _data);
    }
}

// ProxyRegistry
// This factory deploys new proxy instances through build()
// Deployed proxy addresses are logged
contract ProxyRegistry is Title {

    bytes proxyCode = hex"608060405234801561001057600080fd5b5033806000806101000a81548173ffffffffffffffffffffffffffffffffffffffff021916908373ffffffffffffffffffffffffffffffffffffffff1602179055505033600260006101000a81548173ffffffffffffffffffffffffffffffffffffffff021916908373ffffffffffffffffffffffffffffffffffffffff160217905550610a4b806100a36000396000f3fe60806040526004361061004a5760003560e01c80631cff79cd1461004c5780637b103999146101a0578063b7b0422d146101f7578063e243c5fb14610232578063fe7741b51461025d575b005b6101256004803603604081101561006257600080fd5b81019080803573ffffffffffffffffffffffffffffffffffffffff1690602001909291908035906020019064010000000081111561009f57600080fd5b8201836020820111156100b157600080fd5b803590602001918460018302840111640100000000831117156100d357600080fd5b91908080601f016020809104026020016040519081016040528093929190818152602001838380828437600081840152601f19601f82011690508083019250505050505050919291929050505061045b565b6040518080602001828103825283818151815260200191508051906020019080838360005b8381101561016557808201518184015260208101905061014a565b50505050905090810190601f1680156101925780820380516001836020036101000a031916815260200191505b509250505060405180910390f35b3480156101ac57600080fd5b506101b561061d565b604051808273ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16815260200191505060405180910390f35b34801561020357600080fd5b506102306004803603602081101561021a57600080fd5b8101908080359060200190929190505050610643565b005b34801561023e57600080fd5b50610247610688565b6040518082815260200191505060405180910390f35b6103ad6004803603604081101561027357600080fd5b810190808035906020019064010000000081111561029057600080fd5b8201836020820111156102a257600080fd5b803590602001918460018302840111640100000000831117156102c457600080fd5b91908080601f016020809104026020016040519081016040528093929190818152602001838380828437600081840152601f19601f8201169050808301925050505050505091929192908035906020019064010000000081111561032757600080fd5b82018360208201111561033957600080fd5b8035906020019184600183028401116401000000008311171561035b57600080fd5b91908080601f016020809104026020016040519081016040528093929190818152602001838380828437600081840152601f19601f82011690508083019250505050505050919291929050505061068e565b604051808373ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16815260200180602001828103825283818151815260200191508051906020019080838360005b8381101561041f578082015181840152602081019050610404565b50505050905090810190601f16801561044c5780820380516001836020036101000a031916815260200191505b50935050505060405180910390f35b60606001543373ffffffffffffffffffffffffffffffffffffffff166000809054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16636352211e836040518263ffffffff1660e01b815260040180828152602001915050602060405180830381600087803b1580156104eb57600080fd5b505af11580156104ff573d6000803e3d6000fd5b505050506040513d602081101561051557600080fd5b810190808051906020019092919050505073ffffffffffffffffffffffffffffffffffffffff161461054657600080fd5b600073ffffffffffffffffffffffffffffffffffffffff168473ffffffffffffffffffffffffffffffffffffffff1614156105cc576040517f08c379a00000000000000000000000000000000000000000000000000000000081526004018080602001828103825260258152602001806109f26025913960400191505060405180910390fd5b600080845160208601876113885a03f43d6040519350601f19601f6020830101168401604052808452806000602086013e81156001811461060c57610613565b8160208601fd5b5050505092915050565b600260009054906101000a900473ffffffffffffffffffffffffffffffffffffffff1681565b60001515600260149054906101000a900460ff1615151461066357600080fd5b806001819055506001600260146101000a81548160ff02191690831515021790555050565b60015481565b600060606001543373ffffffffffffffffffffffffffffffffffffffff166000809054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16636352211e836040518263ffffffff1660e01b815260040180828152602001915050602060405180830381600087803b15801561072057600080fd5b505af1158015610734573d6000803e3d6000fd5b505050506040513d602081101561074a57600080fd5b810190808051906020019092919050505073ffffffffffffffffffffffffffffffffffffffff161461077b57600080fd5b600260009054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff1663dc16e222866040518263ffffffff1660e01b81526004018080602001828103825283818151815260200191508051906020019080838360005b838110156108095780820151818401526020810190506107ee565b50505050905090810190601f1680156108365780820380516001836020036101000a031916815260200191505b509250505060206040518083038186803b15801561085357600080fd5b505afa158015610867573d6000803e3d6000fd5b505050506040513d602081101561087d57600080fd5b81019080805190602001909291905050509250600073ffffffffffffffffffffffffffffffffffffffff168373ffffffffffffffffffffffffffffffffffffffff1614156109dd57600260009054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16636e7dfa71866040518263ffffffff1660e01b81526004018080602001828103825283818151815260200191508051906020019080838360005b83811015610953578082015181840152602081019050610938565b50505050905090810190601f1680156109805780820380516001836020036101000a031916815260200191505b5092505050602060405180830381600087803b15801561099f57600080fd5b505af11580156109b3573d6000803e3d6000fd5b505050506040513d60208110156109c957600080fd5b810190808051906020019092919050505092505b6109e7838561045b565b915050925092905056fe74696e6c616b652f70726f78792d7461726765742d616464726573732d7265717569726564a265627a7a72315820ccebc7c168ca30474d4391795b241ca898139a55a06d3b1abf8e25550f393acd64736f6c634300050f0032";
    bytes32 proxyCodeHash;

    event Created(address indexed sender, address indexed owner, address proxy, uint tokenId);

    function proxies(uint accessToken) public view returns(address) {
        // create2 address calculation
        // keccak256(0xff ++ deployingAddr ++ salt ++ keccak256(bytecode))[12:]
        bytes32 _data = keccak256(
            abi.encodePacked(bytes1(0xff), address(this), keccak256(abi.encodePacked(accessToken)), proxyCodeHash)
        );
        return address(bytes20(_data << 96));
    }

    constructor() Title("Tinlake Actions Access Token", "TAAT") public {
        proxyCodeHash = keccak256(abi.encodePacked(proxyCode));
    }

    // deploys a new proxy instance
    function build() public returns (address payable proxy) {
        proxy = build(msg.sender);
    }

    // deploys a new proxy instance
    // sets custom owner of proxy by issuing an Title NFT
    function build(address owner) public returns (address payable proxy) {
        uint accessToken = _issue(owner);
        bytes32 salt = keccak256(abi.encodePacked(accessToken));
        proxy = deploy(accessToken, salt);
        emit Created(msg.sender, owner, proxy, accessToken);
    }


    /// uses the create2 opcode to deploy a proxy contract
    function deploy(uint accessToken, bytes32 salt) internal returns (address payable addr) {
        bytes memory code = proxyCode;
        assembly {
            addr := create2(0, add(code, 0x20), mload(code), salt)
            if iszero(extcodesize(addr)) { revert(0, 0) }
        }
        // init contract
        Proxy(addr).init(uint(accessToken));
    }

    // --- Cache ---
    // Copied from ds-proxy/src/proxy.sol:DSProxyCache
    mapping (bytes32 => address) public cache;

    function cacheRead(bytes memory _code) public view returns (address) {
        bytes32 hash = keccak256(_code);
        return cache[hash];
    }

    function cacheWrite(bytes memory _code) public returns (address target) {
        assembly {
            target := create(0, add(_code, 0x20), mload(_code))
            switch iszero(extcodesize(target))
            case 1 {
                // throw if contract failed to deploy
                revert(0, 0)
            }
        }
        bytes32 hash = keccak256(_code);
        cache[hash] = target;
    }
}
