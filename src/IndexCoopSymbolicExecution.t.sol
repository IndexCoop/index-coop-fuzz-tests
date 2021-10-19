// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.6.10;

import "ds-test/test.sol";

import "./IndexCoopSymbolicExecution.sol";

contract IndexCoopSymbolicExecutionTest is DSTest {
    IndexCoopSymbolicExecution execution;

    function setUp() public {
        execution = new IndexCoopSymbolicExecution();
    }

    function prove_password(uint256 _password) public {
        assertTrue(!execution.isPasswordCorrect(_password));
    }
}
