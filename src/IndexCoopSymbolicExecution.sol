// SPDX-License-Identifier: Apache License, Version 2.0
pragma solidity ^0.6.10;

contract IndexCoopSymbolicExecution {
    function isPasswordCorrect(uint256 _password) external pure returns (bool) {
        return _password == 1337;
    }
}
