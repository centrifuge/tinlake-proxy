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

    function testBuildProxy(address randomUser) public {
        vm.prank(randomUser);
        address payable first = registry.build();
        vm.prank(randomUser);
        address payable second = registry.build();
        assertTrue(first != second);
        assertEq(Proxy(first).wards(randomUser), 1);
        assertEq(Proxy(second).wards(randomUser), 1);
        assertEq(Proxy(first).users(randomUser), 0);
        assertEq(Proxy(second).users(randomUser), 0);
    }

    function testProxyOwnerCantExecute(address randomUser) public {
        vm.prank(randomUser);
        address payable proxyAddr = registry.build();
        Proxy proxy = Proxy(proxyAddr);

        bytes memory data = abi.encodeWithSignature("inlineAdd(uint256,uint256)", 5,7);

        // set action as a safe target
        vm.prank(randomUser);
        proxy.file("target", address(action));

        // executing action by proxy owner fails until they are added as user
        vm.prank(randomUser);
        vm.expectRevert(bytes("TinlakeProxy/user-not-authorized"));
        proxy.userExecute(address(action), data);

        // executing action by proxy owner succeeds once owner is added as user
        vm.prank(randomUser);
        proxy.addUser(randomUser);
        vm.prank(randomUser);
        proxy.userExecute(address(action), data);
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

    function testExecute(address user) public {
        address payable proxyAddr = registry.build();
        Proxy proxy = Proxy(proxyAddr);

        bytes memory data = abi.encodeWithSignature("inlineAdd(uint256,uint256)", 5,7);

        // set action as a safe target
        proxy.file("target", address(action));

        // Add this as a user so it can execute
        proxy.addUser(user);

        // execute action that does not call core contract
        vm.prank(user);
        bytes memory response = proxy.userExecute(address(action), data);

        // execute action that does call core contract
        data = abi.encodeWithSignature("doAdd(address,uint256,uint256)", address(core), 5,7);
        vm.prank(user);
        response = proxy.userExecute(address(action), data);

        // msg.sender should be proxy address
        assertEq(core.caller(), proxyAddr);
    }

    function testFailExecuteWithBadData(address user) public {
        address payable proxyAddr = registry.build();
        Proxy proxy = Proxy(proxyAddr);

        // use non-existant function call
        bytes memory data = abi.encodeWithSignature("inlineSubtract(uint256,uint256)", 5,7);

        // set action as a safe target
        proxy.file("target", address(action));

        // Add this as a user so it can execute
        proxy.addUser(user);

        // execute action that does not call core contract
        vm.prank(user);
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

    function testExecuteNotSafeTargetFails(address user) public {
        address payable proxyAddr = registry.build();
        Proxy proxy = Proxy(proxyAddr);

        bytes memory data = abi.encodeWithSignature("inlineAdd(uint256,uint256)", 5,7);

        // set action as a safe target
        // proxy.file("target", address(action));

        // Add this as a user so it can execute
        proxy.addUser(user);

        // execute action that does not call core contract
        vm.prank(user);
        vm.expectRevert(bytes("TinlakeProxy/target-not-authorized"));
        bytes memory response = proxy.userExecute(address(action), data);
    }

    function testFailExecuteAccessActionStorage(address user) public {
        address payable proxyAddr = registry.build();
        Proxy proxy = Proxy(proxyAddr);

        // set action as a safe target
        proxy.file("target", address(action));

        // Add this as a user so it can execute
        proxy.addUser(user);

        // using action contract storage should fail
        bytes memory data = abi.encodeWithSignature("doAdd(uint256,uint256)", 5,7);
        vm.prank(user);
        bytes memory response = proxy.userExecute(address(action), data);
    }
}
