pragma solidity ^0.5.10;

import "ds-test/test.sol";

import "./proxy.sol";

contract ProxyTest is DSTest {
    Proxy proxy;

    function setUp() public {
        proxy = new Proxy();
    }

    function testFail_basic_sanity() public {
        assertTrue(false);
    }

    function test_basic_sanity() public {
        assertTrue(true);
    }
}
