// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

import "ds-test/test.sol";

import "./IndexCoopSymbolicExecution.sol";

contract IndexCoopSymbolicExecutionTest is DSTest {
    IndexCoopSymbolicExecution execution;

    function setUp() public {
        execution = new IndexCoopSymbolicExecution();
    }

    function testFail_basic_sanity() public {
        assertTrue(false);
    }

    function test_basic_sanity() public {
        assertTrue(true);
    }
}
