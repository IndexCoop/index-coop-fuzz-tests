// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.6.10;

import "ds-test/test.sol";

import { BaseManagerV2 } from "indexcoop/contracts/manager/BaseManagerV2.sol";
import { ISetToken as ISetTokenSet } from "setprotocol/contracts/interfaces/ISetToken.sol";
import { ISetToken as ISetTokenIndex } from "indexcoop/contracts/interfaces/ISetToken.sol";

import { SetFixture } from "./utils/SetFixture.sol";

contract IntrinsicProdRebalancing is DSTest {

    SetFixture setFixture;
    BaseManagerV2 baseManager;

    function setUp() public {
        setFixture = new SetFixture();
        baseManager = new BaseManagerV2(ISetTokenIndex(0x1), address(0x2), address(0x3));
    }

    function test_setFixture() public {
        assertEq(address(setFixture.controller()), address(setFixture.basicIssuanceModule().controller()));
    }

    function test_baseMananager() public {
        assertEq(baseManager.getExtensions().length, 0);
    }
}
