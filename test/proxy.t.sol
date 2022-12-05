pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/proxy.sol";

contract SimpleCore {
    address public caller;

    function add(uint256 a, uint256 b) public returns (uint256) {
        caller = msg.sender;
        return a + b;
    }
}

contract SimpleAction {
    SimpleCore core;

    constructor(address core_) {
        core = SimpleCore(core_);
    }

    function inlineAdd(uint256 a, uint256 b) public pure returns (uint256) {
        return a + b;
    }

    function doAdd(address core_, uint256 a, uint256 b) public returns (uint256) {
        return SimpleCore(core_).add(a, b);
    }

    function doAdd(uint256 a, uint256 b) public returns (uint256) {
        return core.add(a, b);
    }

    function coreAddr() public view returns (address) {
        return address(core);
    }
}

contract ProxyTest is Test {
    ProxyRegistry registry;
    SimpleCore core;
    SimpleAction action;

    address defaultUser = address(this);

    function setUp() public {
        registry = new ProxyRegistry();
        core = new SimpleCore();

        // setup proxy lib
        action = new SimpleAction(address(core));
    }

    function testConstructor() public {
        address user = address(0x123);
        Proxy proxy = new Proxy(address(this), user, address(action));
        assertEq(proxy.target(), address(action));
        assertEq(proxy.users(user), 1, "user not added as user");
        assertEq(proxy.wards(address(this)), 1, "test contract should be owner");
        assertEq(proxy.users(address(this)), 0, "test contract should not be user");
        assertEq(proxy.wards(user), 0, "user should not be owner");
    }

    function testAuth(address user, address randomTarget) public {
        address payable proxyAddr = registry.build(address(this), address(0), address(0));
        Proxy proxy = Proxy(proxyAddr);

        // rely user and execute an auth function which succeeds
        proxy.rely(user);
        assertEq(proxy.wards(user), 1);
        vm.prank(user);
        proxy.file("target", randomTarget);
        assertEq(proxy.target(), randomTarget);

        // deny user and execute various auth functions which all revert
        proxy.deny(user);
        assertEq(proxy.wards(user), 0);
        vm.expectRevert(bytes("TinlakeProxy/ward-not-authorized"));
        vm.prank(user);
        proxy.file("target", randomTarget);
    }

    function testUnauthorizedRelyFails(address randomUser) public {
        vm.assume(randomUser != address(this));
        vm.assume(randomUser != address(registry));
        address payable proxyAddr = registry.build(address(this), defaultUser, address(action));
        Proxy proxy = Proxy(proxyAddr);

        vm.expectRevert(bytes("TinlakeProxy/ward-not-authorized"));
        vm.prank(randomUser);
        proxy.rely(randomUser);
    }

    function testUnauthorizedDenyFails(address randomUser) public {
        vm.assume(randomUser != address(this));
        vm.assume(randomUser != address(registry));
        address payable proxyAddr = registry.build(address(this), defaultUser, address(action));
        Proxy proxy = Proxy(proxyAddr);

        vm.expectRevert(bytes("TinlakeProxy/ward-not-authorized"));
        vm.prank(randomUser);
        proxy.deny(address(this));
    }

    function testUnauthorizedAddUserFails(address randomUser) public {
        vm.assume(randomUser != address(this));
        vm.assume(randomUser != address(registry));
        address payable proxyAddr = registry.build(address(this), defaultUser, address(action));
        Proxy proxy = Proxy(proxyAddr);

        vm.expectRevert(bytes("TinlakeProxy/ward-not-authorized"));
        vm.prank(randomUser);
        proxy.addUser(address(this));
    }

    function testUnauthorizedRemoveUserFails(address randomUser) public {
        vm.assume(randomUser != address(this));
        vm.assume(randomUser != address(registry));
        address payable proxyAddr = registry.build(address(this), defaultUser, address(action));
        Proxy proxy = Proxy(proxyAddr);
        proxy.addUser(address(this));

        vm.expectRevert(bytes("TinlakeProxy/ward-not-authorized"));
        vm.prank(randomUser);
        proxy.addUser(address(this));
    }

    function testBuildProxy(address randomUser) public {
        vm.prank(randomUser);
        address payable first = registry.build(randomUser, defaultUser, address(action));
        assertEq(Proxy(first).wards(randomUser), 1);
        assertEq(Proxy(first).users(randomUser), 0);
        assertEq(Proxy(first).users(defaultUser), 1);
        assertEq(Proxy(first).target(), address(action));
    }

    function testBuildProxyWithAddress(address randomUser) public {
        vm.assume(randomUser != address(registry));
        vm.assume(randomUser != address(this));
        address payable first = registry.build(randomUser, defaultUser, address(action));
        assertEq(Proxy(first).wards(address(this)), 0);
        assertEq(Proxy(first).wards(randomUser), 1);
    }

    function testProxyOwnerCantExecute(address randomUser) public {
        vm.prank(randomUser);
        if (randomUser == defaultUser) return;
        address payable proxyAddr = registry.build(randomUser, defaultUser, address(action));
        Proxy proxy = Proxy(proxyAddr);

        bytes memory data = abi.encodeWithSignature("inlineAdd(uint256,uint256)", 5, 7);

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
        address payable proxyAddr = registry.build(address(this), user, address(0x0));
        Proxy proxy = Proxy(proxyAddr);
        // test add target
        proxy.file("target", address(action));
        bytes memory data = abi.encodeWithSignature("inlineAdd(uint256,uint256)", 5, 7);

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
        address payable proxyAddr = registry.build(address(this), defaultUser, address(action));
        Proxy proxy = Proxy(proxyAddr);

        proxy.file("target", _target);
        assertEq(proxy.target(), _target);
    }

    function testUserExecute(address user) public {
        address payable proxyAddr = registry.build(address(this), user, address(action));
        Proxy proxy = Proxy(proxyAddr);

        bytes memory data = abi.encodeWithSignature("inlineAdd(uint256,uint256)", 5, 7);

        // execute action that does not call core contract
        vm.prank(user);
        bytes memory response = proxy.userExecute(address(action), data);

        // check that the response is correct
        assertEq(response.length, 32);
        uint256 result;
        assembly {
            result := mload(add(response, 0x20))
        }
        assertEq(result, 12);

        // execute action that does call core contract
        data = abi.encodeWithSignature("doAdd(address,uint256,uint256)", address(core), 5, 7);
        vm.prank(user);
        response = proxy.userExecute(address(action), data);

        // msg.sender should be proxy address
        assertEq(core.caller(), proxyAddr);
    }

    function testUserExecuteWithBadDataFails(address user) public {
        address payable proxyAddr = registry.build(address(this), user, address(action));
        Proxy proxy = Proxy(proxyAddr);

        // use non-existant function call
        bytes memory data = abi.encodeWithSignature("inlineSubtract(uint256,uint256)", 5, 7);

        // Add this as a user so it can execute
        proxy.addUser(user);

        // execute action that does not call core contract
        vm.prank(user);
        vm.expectRevert();
        proxy.userExecute(address(action), data);
    }

    function testUserExecuteNotUserFails() public {
        address payable proxyAddr = registry.build(address(this), address(0x123), address(action));
        Proxy proxy = Proxy(proxyAddr);

        bytes memory data = abi.encodeWithSignature("inlineAdd(uint256,uint256)", 5, 7);

        // set action as a safe target
        proxy.file("target", address(action));

        // execute action that does not call core contract
        vm.expectRevert(bytes("TinlakeProxy/user-not-authorized"));
        proxy.userExecute(address(action), data);
    }

    function testUserExecuteNotSafeTargetFails(address user) public {
        address payable proxyAddr = registry.build(address(this), user, address(0x0));
        Proxy proxy = Proxy(proxyAddr);

        bytes memory data = abi.encodeWithSignature("inlineAdd(uint256,uint256)", 5, 7);

        // Add this as a user so it can execute
        proxy.addUser(user);

        // execute action that does not call core contract
        vm.prank(user);
        vm.expectRevert(bytes("TinlakeProxy/target-not-authorized"));
        proxy.userExecute(address(action), data);
    }

    function testUserExecuteAccessActionStorageFails(address user) public {
        address payable proxyAddr = registry.build(address(this), user, address(action));
        Proxy proxy = Proxy(proxyAddr);

        // using action contract storage should fail
        bytes memory data = abi.encodeWithSignature("doAdd(uint256,uint256)", 5, 7);
        vm.prank(user);
        vm.expectRevert();
        proxy.userExecute(address(action), data);
    }
}
