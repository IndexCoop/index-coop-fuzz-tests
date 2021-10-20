// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.6.10;

import "ds-test/test.sol";

import { BaseManagerV2 } from "indexcoop/contracts/manager/BaseManagerV2.sol";
import { ISetToken as ISetTokenSet } from "setprotocol/contracts/interfaces/ISetToken.sol";
import { ISetToken as ISetTokenIndex } from "indexcoop/contracts/interfaces/ISetToken.sol";
import { SetTokenCreator } from "setprotocol/contracts/protocol/SetTokenCreator.sol";

import { SetFixture } from "./utils/SetFixture.sol";

contract IntrinsicProdRebalancing is DSTest {

    SetFixture setFixture;
    BaseManagerV2 baseManager;

    function setUp() public {
        setFixture = new SetFixture();
        SetTokenCreator factory = setFixture.setTokenCreator();

        address[] memory components = new address[](1);
        components[0] = address(0x1);

        int256[] memory units = new int256[](1);
        units[0] = 1 ether;

        address[] memory modules = new address[](4);
        modules[0] = address(setFixture.generalIndexModule());
        modules[1] = address(setFixture.basicIssuanceModule());
        modules[2] = address(setFixture.airdropModule());
        modules[3] = address(setFixture.wrapModuleV2());

        ISetTokenIndex setToken = ISetTokenIndex(factory.create(components, units, modules, address(this), "Test Yield Set", "YIELD"));

        baseManager = new BaseManagerV2(setToken, address(0x2), address(0x3));
    }

    function test_setFixture() public {
        assertEq(address(setFixture.controller()), address(setFixture.basicIssuanceModule().controller()));
    }

    function test_baseMananager() public {
        assertEq(baseManager.getExtensions().length, 0);
    }
}
