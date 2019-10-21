pragma solidity ^0.5.10;

import "ds-test/test.sol";

import "./proxy.sol";
import "tinlake/title.sol";


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
    function coreAddr() public returns(address) {
        return address(core);
    }
}

contract ProxyTest is DSTest {
    Title title;
    ProxyFactory factory;
    SimpleCore core;
    SimpleAction action;

    function setUp() public {
        title = new Title("Tinlake", "TLO");
        factory = new ProxyFactory(address(title));
        title.rely(address(factory));

        core = new SimpleCore();

        // setup proxy lib
        action = new SimpleAction(address(core));
    }

    function testBuildProxy() public {
        address payable first = factory.build();
        Proxy proxy = Proxy(first);
        assertEq(proxy.accessToken(), 0);

        address payable second = factory.build();
        assertTrue(first != second);
        proxy = Proxy(second);
        assertEq(proxy.accessToken(), 1);
    }

    function testExecute() public {
        address payable proxyAddr = factory.build();
        Proxy proxy = Proxy(proxyAddr);

        bytes memory data = abi.encodeWithSignature("inlineAdd(uint256,uint256)", 5,7);

        // action not calling other method
        bytes memory response = proxy.execute(address(action), data);

        // using core
        data = abi.encodeWithSignature("doAdd(address,uint256,uint256)", address(core), 5,7);
        response = proxy.execute(address(action), data);

        // msg.sender should be proxy address
        assertEq(core.caller(), proxyAddr);

    }

    function testFailExecute() public {
        address payable proxyAddr = factory.build();
        Proxy proxy = Proxy(proxyAddr);

        uint accessToken = proxy.accessToken();
        title.transferFrom(msg.sender,address(123), accessToken);

        // using core
        bytes memory data = abi.encodeWithSignature("doAdd(address,uint256,uint256)", address(core), 5,7);

        // should fail because doesn't own accessToken anymore
        bytes memory  response = proxy.execute(address(action), data);
    }
}
