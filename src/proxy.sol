// proxy.sol - execute actions atomically through the proxy's identity

// Copyright (C) 2017  DappHub, LLC

// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

pragma solidity >=0.5.0 <0.6.0;

import "tinlake/title.sol";

// Original DSProxy https://github.com/dapphub/ds-proxy
contract Proxy is TitleOwned {
    uint public accessToken;

    constructor(address title_, uint accessToken_) TitleOwned(title_) public {
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
        require(_target != address(0), "ds-proxy-target-address-required");

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
}

contract TitleLike_ {
    function count() public returns(uint);
    function issue(address usr) public returns(uint);
}


// ProxyFactory
// This factory deploys new proxy instances through build()
// Deployed proxy addresses are logged
contract ProxyFactory {
    event Created(address indexed sender, address indexed owner, address proxy);
    mapping(address=>bool) public isProxy;

    TitleLike_ title;

    constructor(address title_) public {
        title = TitleLike_(title_);
    }

    // deploys a new proxy instance
    // sets owner of proxy to caller
    function build() public returns (address payable proxy) {
        proxy = build(msg.sender);
    }

    // deploys a new proxy instance
    // sets custom owner of proxy
    function build(address owner) public returns (address payable proxy) {
        uint id = title.count();
        proxy = address(new Proxy(address(title), id));
        uint token = title.issue(owner);
        require(id == token);

        emit Created(msg.sender, owner, address(proxy));
        isProxy[proxy] = true;
    }
}
