pragma solidity >=0.6.0 < 0.9.0;

import "forge-std/Test.sol";
import "../src/proxy.sol";


contract SimpleCore {
    address public caller;

    function add(uint256 a, uint256 b) public returns (uint256) {
        caller = msg.sender;
        return a+b;
    }
}

contract SimpleAction {
    SimpleCore core;
    constructor(address core_) public {
        core = SimpleCore(core_);
    }

    function inlineAdd(uint256 a, uint256 b) public returns (uint256) {
        return a+b;
    }

    function doAdd(address core_, uint256 a, uint256 b) public returns (uint256) {
        return SimpleCore(core_).add(a,b);
    }

    function doAdd(uint256 a, uint256 b) public returns (uint256) {
        return core.add(a,b);
    }

    function coreAddr() public returns(address) {
        return address(core);
    }
}

contract ProxyTest is DSTest {
    ProxyRegistry registry;
    SimpleCore    core;
    SimpleAction  action;

    function setUp() public {
        registry = new ProxyRegistry();
        core = new SimpleCore();

        // setup proxy lib
        action = new SimpleAction(address(core));
    }

    function testBuildProxy() public {
        address payable first = registry.build();
        address payable second = registry.build();
        assertTrue(first != second);
    }

    function testExecute() public {
        address payable proxyAddr = registry.build();
        Proxy proxy = Proxy(proxyAddr);

        bytes memory data = abi.encodeWithSignature("inlineAdd(uint256,uint256)", 5,7);

        // set action as a safe target
        proxy.safe(address(action));

        // Add this as a user so it can execute
        proxy.addUser(address(this));

        // action not calling other method
        bytes memory response = proxy.userExecute(address(action), data);

        // using core
        data = abi.encodeWithSignature("doAdd(address,uint256,uint256)", address(core), 5,7);
        response = proxy.userExecute(address(action), data);

        // msg.sender should be proxy address
        assertEq(core.caller(), proxyAddr);
    }

    function testFailExecuteNotUser() public {
        address payable proxyAddr = registry.build();
        Proxy proxy = Proxy(proxyAddr);

        bytes memory data = abi.encodeWithSignature("inlineAdd(uint256,uint256)", 5,7);

        // set action as a safe target
        proxy.safe(address(action));

        // Add this as a user so it can execute
        // proxy.addUser(address(this));

        // action not calling other method
        bytes memory response = proxy.userExecute(address(action), data);

        // using core
        data = abi.encodeWithSignature("doAdd(address,uint256,uint256)", address(core), 5,7);
        response = proxy.userExecute(address(action), data);

        // msg.sender should be proxy address
        assertEq(core.caller(), proxyAddr);
    }

    function testRemovingUser(address user) public {
        address payable proxyAddr = registry.build();
        Proxy proxy = Proxy(proxyAddr);

        // Add a random user
        proxy.addUser(user);
        assertEq(proxy.users(user), 1);

        // remove user
        proxy.removeUser(user);
        assertEq(proxy.users(user), 0);

    }

    function testFailExecuteNotSafe() public {
        address payable proxyAddr = registry.build();
        Proxy proxy = Proxy(proxyAddr);

        bytes memory data = abi.encodeWithSignature("inlineAdd(uint256,uint256)", 5,7);

        // set action as a safe target
        // proxy.safe(address(action));

        // Add this as a user so it can execute
        proxy.addUser(address(this));

        // action not calling other method
        bytes memory response = proxy.userExecute(address(action), data);

        // using core
        data = abi.encodeWithSignature("doAdd(address,uint256,uint256)", address(core), 5,7);
        response = proxy.userExecute(address(action), data);

        // msg.sender should be proxy address
        assertEq(core.caller(), proxyAddr);
    }

    function testFailExecuteAccessActionStorage() public {
        address payable proxyAddr = registry.build();
        Proxy proxy = Proxy(proxyAddr);

        // set action as a safe target
        proxy.safe(address(action));

        // Add this as a user so it can execute
        proxy.addUser(address(this));

        // using action contract storage should fail
        bytes memory data = abi.encodeWithSignature("doAdd(uint256,uint256)", address(core), 5,7);
        bytes memory response = proxy.userExecute(address(action), data);
    }
}
