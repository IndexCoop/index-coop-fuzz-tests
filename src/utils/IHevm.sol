// SPDX-License-Identifier: MIT
pragma solidity 0.6.10;
pragma experimental "ABIEncoderV2";

interface IHevm {
    function ffi(string[] calldata) external returns (bytes memory);
}