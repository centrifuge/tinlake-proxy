pragma solidity ^0.5.10;

import "ds-test/test.sol";

import "./TinlakeActions.sol";

contract TinlakeActionsTest is DSTest {
    TinlakeActions actions;

    function setUp() public {
        actions = new TinlakeActions();
    }

    function testFail_basic_sanity() public {
        assertTrue(false);
    }

    function test_basic_sanity() public {
        assertTrue(true);
    }
}
