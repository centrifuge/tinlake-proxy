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

    constructor(uint accessToken_) TitleOwned(msg.sender) public {
        registry = RegistryLike(msg.sender);
        accessToken = accessToken_;
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

    bytes proxyCode = hex"608060405234801561001057600080fd5b50604051610a9e380380610a9e8339818101604052602081101561003357600080fd5b810190808051906020019092919050505033806000806101000a81548173ffffffffffffffffffffffffffffffffffffffff021916908373ffffffffffffffffffffffffffffffffffffffff1602179055505033600260006101000a81548173ffffffffffffffffffffffffffffffffffffffff021916908373ffffffffffffffffffffffffffffffffffffffff16021790555080600181905550506109c0806100de6000396000f3fe60806040526004361061003f5760003560e01c80631cff79cd146100415780637b10399914610195578063e243c5fb146101ec578063fe7741b514610217575b005b61011a6004803603604081101561005757600080fd5b81019080803573ffffffffffffffffffffffffffffffffffffffff1690602001909291908035906020019064010000000081111561009457600080fd5b8201836020820111156100a657600080fd5b803590602001918460018302840111640100000000831117156100c857600080fd5b91908080601f016020809104026020016040519081016040528093929190818152602001838380828437600081840152601f19601f820116905080830192505050505050509192919290505050610415565b6040518080602001828103825283818151815260200191508051906020019080838360005b8381101561015a57808201518184015260208101905061013f565b50505050905090810190601f1680156101875780820380516001836020036101000a031916815260200191505b509250505060405180910390f35b3480156101a157600080fd5b506101aa6105d7565b604051808273ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16815260200191505060405180910390f35b3480156101f857600080fd5b506102016105fd565b6040518082815260200191505060405180910390f35b6103676004803603604081101561022d57600080fd5b810190808035906020019064010000000081111561024a57600080fd5b82018360208201111561025c57600080fd5b8035906020019184600183028401116401000000008311171561027e57600080fd5b91908080601f016020809104026020016040519081016040528093929190818152602001838380828437600081840152601f19601f820116905080830192505050505050509192919290803590602001906401000000008111156102e157600080fd5b8201836020820111156102f357600080fd5b8035906020019184600183028401116401000000008311171561031557600080fd5b91908080601f016020809104026020016040519081016040528093929190818152602001838380828437600081840152601f19601f820116905080830192505050505050509192919290505050610603565b604051808373ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16815260200180602001828103825283818151815260200191508051906020019080838360005b838110156103d95780820151818401526020810190506103be565b50505050905090810190601f1680156104065780820380516001836020036101000a031916815260200191505b50935050505060405180910390f35b60606001543373ffffffffffffffffffffffffffffffffffffffff166000809054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16636352211e836040518263ffffffff1660e01b815260040180828152602001915050602060405180830381600087803b1580156104a557600080fd5b505af11580156104b9573d6000803e3d6000fd5b505050506040513d60208110156104cf57600080fd5b810190808051906020019092919050505073ffffffffffffffffffffffffffffffffffffffff161461050057600080fd5b600073ffffffffffffffffffffffffffffffffffffffff168473ffffffffffffffffffffffffffffffffffffffff161415610586576040517f08c379a00000000000000000000000000000000000000000000000000000000081526004018080602001828103825260258152602001806109676025913960400191505060405180910390fd5b600080845160208601876113885a03f43d6040519350601f19601f6020830101168401604052808452806000602086013e8115600181146105c6576105cd565b8160208601fd5b5050505092915050565b600260009054906101000a900473ffffffffffffffffffffffffffffffffffffffff1681565b60015481565b600060606001543373ffffffffffffffffffffffffffffffffffffffff166000809054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16636352211e836040518263ffffffff1660e01b815260040180828152602001915050602060405180830381600087803b15801561069557600080fd5b505af11580156106a9573d6000803e3d6000fd5b505050506040513d60208110156106bf57600080fd5b810190808051906020019092919050505073ffffffffffffffffffffffffffffffffffffffff16146106f057600080fd5b600260009054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff1663dc16e222866040518263ffffffff1660e01b81526004018080602001828103825283818151815260200191508051906020019080838360005b8381101561077e578082015181840152602081019050610763565b50505050905090810190601f1680156107ab5780820380516001836020036101000a031916815260200191505b509250505060206040518083038186803b1580156107c857600080fd5b505afa1580156107dc573d6000803e3d6000fd5b505050506040513d60208110156107f257600080fd5b81019080805190602001909291905050509250600073ffffffffffffffffffffffffffffffffffffffff168373ffffffffffffffffffffffffffffffffffffffff16141561095257600260009054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16636e7dfa71866040518263ffffffff1660e01b81526004018080602001828103825283818151815260200191508051906020019080838360005b838110156108c85780820151818401526020810190506108ad565b50505050905090810190601f1680156108f55780820380516001836020036101000a031916815260200191505b5092505050602060405180830381600087803b15801561091457600080fd5b505af1158015610928573d6000803e3d6000fd5b505050506040513d602081101561093e57600080fd5b810190808051906020019092919050505092505b61095c8385610415565b915050925092905056fe74696e6c616b652f70726f78792d7461726765742d616464726573732d7265717569726564a265627a7a7231582047efb82183565e484108d88c2fa9e493326dd8b3ee172c762d0a60ea0dc04e1464736f6c634300050f0032";

    event Created(address indexed sender, address indexed owner, address proxy, uint tokenId);

    function proxies(uint accessToken) public view returns(address) {
        // create2 address calculation
        // keccak256(0xff ++ deployingAddr ++ salt ++ keccak256(bytecode))[12:]
        // the deployingAddr is address(this)
        // the salt is the keccak256(accessToken)
        // for the bytecode we concat the constructor param
        bytes32 codeHash = keccak256(abi.encodePacked(proxyCode, abi.encodePacked(accessToken)));
        bytes32 _data = keccak256(
            abi.encodePacked(bytes1(0xff), address(this), keccak256(abi.encodePacked(accessToken)), codeHash)
        );
        return address(bytes20(_data << 96));
    }

    constructor() Title("Tinlake Actions Access Token", "TAAT") public {
    }

    // deploys a new proxy instance
    function build() public returns (address payable proxy) {
        proxy = build(msg.sender);
    }

    // deploys a new proxy instance
    // sets custom owner of proxy by issuing an Title NFT
    function build(address owner) public returns (address payable proxy) {
        uint token = _issue(owner);
        bytes memory tokenHex = abi.encodePacked(token);
        proxy = deploy(tokenHex);
        emit Created(msg.sender, owner, proxy, token);
    }


    /// uses the create2 opcode to deploy a proxy contract
    function deploy(bytes memory accessToken) internal returns (address payable addr) {

        // constructor parameter are part of the contract byte code
        // in our case a specific init method is not required
        // because the only parameter is the accessToken
        bytes memory code = abi.encodePacked(proxyCode, accessToken);
        bytes32 salt = keccak256(accessToken);

        assembly {
            addr := create2(0, add(code, 0x20), mload(code), salt)
            if iszero(extcodesize(addr)) { revert(0, 0) }
        }
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
