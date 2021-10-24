// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.6.10;

import "ds-test/test.sol";

import { BaseManagerV2 } from "indexcoop/contracts/manager/BaseManagerV2.sol";
import { CompoundWrapV2Adapter } from "setprotocol/contracts/protocol/integration/wrap-v2/CompoundWrapV2Adapter.sol";
import { IPRebalanceExtension } from "indexcoop/contracts/adapters/IPRebalanceExtension.sol";
import { SetTokenCreator } from "setprotocol/contracts/protocol/SetTokenCreator.sol";
import { StandardTokenMock } from "indexcoop/contracts/mocks/StandardTokenMock.sol";
import { TransformHelperMock } from "indexcoop/contracts/mocks/TransformHelperMock.sol";
import { WrapTokenMock} from "indexcoop/contracts/mocks/WrapTokenMock.sol";

import { IBaseManager } from "indexcoop/contracts/interfaces/IBaseManager.sol";
import { IGeneralIndexModule } from "indexcoop/contracts/interfaces/IGeneralIndexModule.sol";
import { IAirdropModule } from "indexcoop/contracts/interfaces/IAirdropModule.sol";
import { ISetToken as ISetTokenSet } from "setprotocol/contracts/interfaces/ISetToken.sol";
import { ISetToken as ISetTokenIndex } from "indexcoop/contracts/interfaces/ISetToken.sol";

import { PreciseUnitMath } from "indexcoop/contracts/lib/PreciseUnitMath.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/SafeCast.sol";

import { SetFixture } from "./utils/SetFixture.sol";

contract IntrinsicProdRebalancing is DSTest {
    using PreciseUnitMath for uint256;
    using SafeCast for uint256;

    SetFixture setFixture;
    BaseManagerV2 baseManager;
    IPRebalanceExtension ipRebalanceExtension;

    StandardTokenMock dai;
    WrapTokenMock cDai;

    uint256 cDaiExchangeRate;
    TransformHelperMock compTransformHelper;

    function setUp() public {
        setFixture = new SetFixture(address(this));
        SetTokenCreator factory = setFixture.setTokenCreator();

        address[] memory modules = new address[](4);
        modules[0] = address(setFixture.generalIndexModule());
        modules[1] = address(setFixture.basicIssuanceModule());
        modules[2] = address(setFixture.airdropModule());
        modules[3] = address(setFixture.wrapModuleV2());

        // create mock components
        dai = new StandardTokenMock(address(this), 10000 ether, "DAI", "DAI", 18);
        cDaiExchangeRate = 1.19438 ether;
        cDai = new WrapTokenMock("Compound Dai", "cDAI", 18, dai, cDaiExchangeRate);

        // create set
        address[] memory components = new address[](2);
        components[0] = address(dai);
        components[1] = address(cDai);

        int256[] memory units = new int256[](2);
        units[0] = 0.7 ether;
        units[1] = cDaiExchangeRate.preciseMul(0.3 ether).toInt256();

        ISetTokenIndex setToken = ISetTokenIndex(factory.create(components, units, modules, address(this), "Test Yield Set", "YIELD"));
        baseManager = new BaseManagerV2(setToken, address(this), address(0x3));

        // deploy IPRebalanceExtension
        ipRebalanceExtension = new IPRebalanceExtension(
            IBaseManager(address(baseManager)),
            IGeneralIndexModule(address(setFixture.generalIndexModule())),
            IAirdropModule(address(setFixture.airdropModule()))
        );

        // deploy TransferHelpers
        compTransformHelper = new TransformHelperMock(cDaiExchangeRate, address(setFixture.wrapModuleV2()), "MockWrapV2Adapter");

        // setup wrap adapter
        CompoundWrapV2Adapter wrapAdapter = new CompoundWrapV2Adapter();
        setFixture.integrationRegistry().addIntegration(address(setFixture.wrapModuleV2()), "MockWrapV2Adapter", address(wrapAdapter));
    }

    function test_setFixture() public {
        assertEq(address(setFixture.controller()), address(setFixture.basicIssuanceModule().controller()));
    }

    function test_baseMananager() public {
        assertEq(baseManager.getExtensions().length, 0);
    }
}
