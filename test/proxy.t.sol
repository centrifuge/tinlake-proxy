pragma solidity >=0.6.0 <0.8.0;

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

contract ProxyTest is Test {
    ProxyRegistry registry;
    SimpleCore    core;
    SimpleAction  action;

    function setUp() public {
        registry = new ProxyRegistry();
        core = new SimpleCore();

        // setup proxy lib
        action = new SimpleAction(address(core));
    }

    function testAuth(address user, address randomTarget) public {
        address payable proxyAddr = registry.build();
        Proxy proxy = Proxy(proxyAddr);
        
        // rely user and execute an auth function which succeeds
        proxy.rely(user);
        assertEq(proxy.wards(user), 1);
        vm.prank(user);
        proxy.file("target", randomTarget);
        assertEq(proxy.target(), randomTarget);

        // deny user and execute an auth function which reverts
        proxy.deny(user);
        assertEq(proxy.wards(user), 0);
        vm.expectRevert(bytes("TinlakeProxy/ward-not-authorized"));
        vm.prank(user);
        proxy.file("target", randomTarget);
    }

    function testBuildProxy() public {
        address payable first = registry.build();
        address payable second = registry.build();
        assertTrue(first != second);
    }

    function testAddRemoveUser(address user) public {
        address payable proxyAddr = registry.build();
        Proxy proxy = Proxy(proxyAddr);
        proxy.file("target", address(action));
        bytes memory data = abi.encodeWithSignature("inlineAdd(uint256,uint256)", 5,7);

        // Add a random user
        proxy.addUser(user);
        assertEq(proxy.users(user), 1);

        // test executing target actions with user
        vm.prank(user);
        proxy.userExecute(address(action), data);

        // remove user
        proxy.removeUser(user);
        assertEq(proxy.users(user), 0);
        vm.prank(user);
        vm.expectRevert(bytes("TinlakeProxy/user-not-authorized"));
        proxy.userExecute(address(action), data);
    }

    function testAddTarget(address _target) public {
        address payable proxyAddr = registry.build();
        Proxy proxy = Proxy(proxyAddr);

        proxy.file("target", _target);
        assertEq(proxy.target(), _target);
    }

    function testExecute() public {
        address payable proxyAddr = registry.build();
        Proxy proxy = Proxy(proxyAddr);

        bytes memory data = abi.encodeWithSignature("inlineAdd(uint256,uint256)", 5,7);

        // set action as a safe target
        proxy.file("target", address(action));

        // Add this as a user so it can execute
        proxy.addUser(address(this));

        // execute action that does not call core contract
        bytes memory response = proxy.userExecute(address(action), data);

        // execute action that does call core contract
        data = abi.encodeWithSignature("doAdd(address,uint256,uint256)", address(core), 5,7);
        response = proxy.userExecute(address(action), data);

        // msg.sender should be proxy address
        assertEq(core.caller(), proxyAddr);
    }

    function testFailExecuteWithBadData() public {
        address payable proxyAddr = registry.build();
        Proxy proxy = Proxy(proxyAddr);

        // use non-existant function call
        bytes memory data = abi.encodeWithSignature("inlineSubtract(uint256,uint256)", 5,7);

        // set action as a safe target
        proxy.file("target", address(action));

        // Add this as a user so it can execute
        proxy.addUser(address(this));

        // execute action that does not call core contract
        bytes memory response = proxy.userExecute(address(action), data);
    }

    function testExecuteNotUserFails() public {
        address payable proxyAddr = registry.build();
        Proxy proxy = Proxy(proxyAddr);

        bytes memory data = abi.encodeWithSignature("inlineAdd(uint256,uint256)", 5,7);

        // set action as a safe target
        proxy.file("target", address(action));

        // Add this as a user so it can execute
        // proxy.addUser(address(this));

        // execute action that does not call core contract
        vm.expectRevert(bytes("TinlakeProxy/user-not-authorized"));
        bytes memory response = proxy.userExecute(address(action), data);
    }

    function testExecuteNotSafeTargetFails() public {
        address payable proxyAddr = registry.build();
        Proxy proxy = Proxy(proxyAddr);

        bytes memory data = abi.encodeWithSignature("inlineAdd(uint256,uint256)", 5,7);

        // set action as a safe target
        // proxy.file("target", address(action));

        // Add this as a user so it can execute
        proxy.addUser(address(this));

        // execute action that does not call core contract
        vm.expectRevert(bytes("TinlakeProxy/target-not-authorized"));
        bytes memory response = proxy.userExecute(address(action), data);
    }

    function testFailExecuteAccessActionStorage() public {
        address payable proxyAddr = registry.build();
        Proxy proxy = Proxy(proxyAddr);

        // set action as a safe target
        proxy.file("target", address(action));

        // Add this as a user so it can execute
        proxy.addUser(address(this));

        // using action contract storage should fail
        bytes memory data = abi.encodeWithSignature("doAdd(uint256,uint256)", 5,7);
        bytes memory response = proxy.userExecute(address(action), data);
    }
}
