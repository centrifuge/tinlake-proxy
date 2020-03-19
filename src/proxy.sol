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

    constructor() TitleOwned(msg.sender) public {
        registry = RegistryLike(msg.sender);
    }

    function init(uint accessToken_) public {
        require(accessToken == 0);
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

    bytes32 proxyCodeHash;
    bytes public proxyCode;

    event Created(address indexed sender, address indexed owner, address proxy, uint tokenId);

    function proxies(uint accessToken) public view returns(address) {
        // create2 address calculation
        // keccak256(0xff ++ deployingAddr ++ salt ++ keccak256(bytecode))[12:]

        // constructor without parameters results in the same proxyCodeHash for all proxies
        // expensive rehashing not required
        bytes32 _data = keccak256(
            abi.encodePacked(bytes1(0xff), address(this), keccak256(abi.encodePacked(accessToken)), proxyCodeHash)
        );
        return address(bytes20(_data << 96));
    }

    constructor() Title("Tinlake Proxy Access Token", "TAAT") public {
        proxyCode = type(Proxy).creationCode;
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

        bytes memory code = proxyCode;
        assembly {
            proxy := create2(0, add(code, 0x20), mload(code), salt)
            if iszero(extcodesize(addr)) { revert(0, 0) }
        }
        // init proxy contract
        Proxy(proxy).init(uint(accessToken));

        emit Created(msg.sender, owner, proxy, accessToken);
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
