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

pragma solidity >=0.6.0 <0.8.0;

interface RegistryLike {
    function cacheRead(bytes memory _code) external view returns (address);
    function cacheWrite(bytes memory _code) external returns (address target);
}

contract Proxy {

    mapping(address => uint256) public wards;
    mapping(address => uint256) public users;
    address public target; // target contract that can be called by users

    RegistryLike public registry;

    event UserAdded(address user);
    event UserRemoved(address user);
    event Rely(address indexed user);
    event Deny(address indexed user);
    event File(bytes32 what, address _target);

    modifier user {
        require(users[msg.sender] == 1, "TinlakeProxy/user-not-authorized");
        _;
    }

    modifier auth {
        require(wards[msg.sender] == 1, "TinlakeProxy/ward-not-authorized");
        _;
    }

    constructor() {
        wards[msg.sender] = 1;
        emit Rely(msg.sender);
    }

    // --- Administration ---
    function rely(address usr) external auth {
        wards[usr] = 1;
        emit Rely(usr);
    }

    function deny(address usr) external auth {
        wards[usr] = 0;
        emit Deny(usr);
    }

    function addUser(address usr) external auth {
        users[usr] = 1;
        emit UserAdded(usr);
    }

    function removeUser(address usr) external auth {
        users[usr] = 0;
        emit UserRemoved(usr);
    }

    function file(bytes32 what, address data) external auth {
        if (what == "target") target = data;
        else revert("TinlakeProxy/file-unrecognized-param");
        emit File(what, data);
    }

    // --- Proxy ---
    function userExecute(address _target, bytes memory _data)
    public
    payable
    user
    returns (bytes memory response)
    {
        require(_target != address(0), "TinlakeProxy/target-address-required");
        require(target == _target, "TinlakeProxy/target-not-authorized");
        execute(_target, _data);
     }

    
    function execute(address _target, bytes memory _data)
    internal
    returns (bytes memory response)
    {
        // call contract in current context
        assembly {
            let succeeded := delegatecall(sub(gas(), 5000), _target, add(_data, 0x20), mload(_data), 0, 0)
            let size := returndatasize()

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
}

// ProxyRegistry: This factory deploys new proxy instances through build()
contract ProxyRegistry {

    event Created(address indexed sender, address indexed owner, address proxy);

    // deploys a new proxy instance
    function build() public returns (address payable proxy) {
        proxy = build(msg.sender);
    }

    // deploys a new proxy instance
    function build(address owner) public returns (address payable proxyAddr) {
        Proxy proxy = new Proxy();
        
        // add first owner
        proxy.rely(owner);

        emit Created(msg.sender, owner, address(proxy));
        
        return payable(address(proxy));
    }
}
