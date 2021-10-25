// SPDX-License-Identifier: MIT
pragma solidity 0.6.10;
pragma experimental ABIEncoderV2;

import "ds-test/test.sol";

import { BaseManagerV2 } from "indexcoop/contracts/manager/BaseManagerV2.sol";
import { CompoundWrapV2Adapter } from "setprotocol/contracts/protocol/integration/wrap-v2/CompoundWrapV2Adapter.sol";
import { IPRebalanceExtension } from "indexcoop/contracts/adapters/IPRebalanceExtension.sol";
import { SetTokenCreator } from "setprotocol/contracts/protocol/SetTokenCreator.sol";
import { StandardTokenMock } from "indexcoop/contracts/mocks/StandardTokenMock.sol";
import { TransformHelperMock } from "indexcoop/contracts/mocks/TransformHelperMock.sol";
import { WrapTokenMock} from "indexcoop/contracts/mocks/WrapTokenMock.sol";

import { IAirdropModule } from "indexcoop/contracts/interfaces/IAirdropModule.sol";
import { IBaseManager } from "indexcoop/contracts/interfaces/IBaseManager.sol";
import { IGeneralIndexModule } from "indexcoop/contracts/interfaces/IGeneralIndexModule.sol";
import { IManagerIssuanceHook } from "setprotocol/contracts/interfaces/IManagerIssuanceHook.sol";
import { ISetToken as ISetTokenSet } from "setprotocol/contracts/interfaces/ISetToken.sol";
import { ISetToken as ISetTokenIndex } from "indexcoop/contracts/interfaces/ISetToken.sol";
import { ITransformHelper } from "indexcoop/contracts/interfaces/ITransformHelper.sol";

import { PreciseUnitMath } from "indexcoop/contracts/lib/PreciseUnitMath.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/SafeCast.sol";

import { SetFixture } from "./utils/SetFixture.sol";

contract IntrinsicProdRebalancing is DSTest {
    using PreciseUnitMath for uint256;
    using SafeCast for uint256;
    using SafeCast for int256;

    SetFixture setFixture;
    ISetTokenIndex setToken;
    BaseManagerV2 baseManager;
    IPRebalanceExtension ipRebalanceExtension;

    address[] components;

    StandardTokenMock dai;
    WrapTokenMock cDai;
    WrapTokenMock yDai;

    uint256 cDaiExchangeRate;
    TransformHelperMock compTransformHelper;
    uint256 yDaiExchangeRate;
    TransformHelperMock yearnTransformHelper;

    function setUp() public {
        setFixture = new SetFixture(address(this));
        SetTokenCreator factory = setFixture.setTokenCreator();

        address[] memory modules = new address[](4);
        modules[0] = address(setFixture.generalIndexModule());
        modules[1] = address(setFixture.basicIssuanceModule());
        modules[2] = address(setFixture.airdropModule());
        modules[3] = address(setFixture.wrapModuleV2());

        // create mock components
        dai = new StandardTokenMock(address(this), 2**256-1, "DAI", "DAI", 18);
        cDaiExchangeRate = 1.19438 ether;
        cDai = new WrapTokenMock("Compound Dai", "cDAI", 18, dai, cDaiExchangeRate);
        dai.approve(address(cDai), 2**96);
        cDai.mint(2**96);

        yDaiExchangeRate = 1.3412939 ether;
        yDai = new WrapTokenMock("Yearn Dai", "yDAI", 18, dai, yDaiExchangeRate);
        dai.approve(address(yDai), 2**96);
        yDai.mint(2**96);

        // create set
        components = new address[](3);
        components[0] = address(dai);
        components[1] = address(cDai);
        components[2] = address(yDai);

        int256[] memory units = new int256[](3);
        units[0] = 0.7 ether;
        units[1] = cDaiExchangeRate.preciseMul(0.3 ether).toInt256();
        units[2] = yDaiExchangeRate.preciseMul(1.2 ether).toInt256();

        setToken = ISetTokenIndex(factory.create(components, units, modules, address(this), "Test Yield Set", "YIELD"));
        baseManager = new BaseManagerV2(setToken, address(this), address(this));
        baseManager.authorizeInitialization();
        setFixture.wrapModuleV2().initialize(ISetTokenSet(address(setToken)));
        setFixture.basicIssuanceModule().initialize(ISetTokenSet(address(setToken)), IManagerIssuanceHook(address(0)));
        setFixture.generalIndexModule().initialize(ISetTokenSet(address(setToken)));
        setToken.setManager(address(baseManager));

        // issue some sets
        cDai.approve(address(setFixture.basicIssuanceModule()), 1000000 ether);
        yDai.approve(address(setFixture.basicIssuanceModule()), 1000000 ether);
        dai.approve(address(setFixture.basicIssuanceModule()), 1000000 ether);
        setFixture.basicIssuanceModule().issue(ISetTokenSet(address(setToken)), 5.1 ether, address(this));

        // setup IPRebalanceExtension
        ipRebalanceExtension = new IPRebalanceExtension(
            IBaseManager(address(baseManager)),
            IGeneralIndexModule(address(setFixture.generalIndexModule())),
            IAirdropModule(address(setFixture.airdropModule()))
        );
        address[] memory callers = new address[](1);
        callers[0] = address(this);
        bool[] memory statuses = new bool[](1);
        statuses[0] = true;
        ipRebalanceExtension.updateCallerStatus(callers, statuses);
        baseManager.addExtension(address(ipRebalanceExtension));

        // setup wrap adapter
        CompoundWrapV2Adapter wrapAdapter = new CompoundWrapV2Adapter();
        setFixture.integrationRegistry().addIntegration(address(setFixture.wrapModuleV2()), "MockWrapV2Adapter", address(wrapAdapter));

        // setup TransferHelpers
        compTransformHelper = new TransformHelperMock(cDaiExchangeRate, address(setFixture.wrapModuleV2()), "MockWrapV2Adapter");
        ipRebalanceExtension.setTransformInfo(
            address(cDai),
            IPRebalanceExtension.TransformInfo(address(dai), ITransformHelper(address(compTransformHelper)))
        );

        yearnTransformHelper = new TransformHelperMock(yDaiExchangeRate, address(setFixture.wrapModuleV2()), "MockWrapV2Adapter");
        ipRebalanceExtension.setTransformInfo(
            address(yDai),
            IPRebalanceExtension.TransformInfo(address(dai), ITransformHelper(address(yearnTransformHelper)))
        );
    }

    function test_untransform(uint96 targetDaiUnits, uint96 targetCDaiUnitsUnderlying, uint96 targetYDaiUnitsUnderlying) public {
        uint256[] memory units = new uint256[](3);
        units[0] = targetDaiUnits;
        units[1] = targetCDaiUnitsUnderlying;
        units[2] = targetYDaiUnitsUnderlying;

        ipRebalanceExtension.startIPRebalance(components, units);

        uint256 initCDaiUnits = setToken.getDefaultPositionRealUnit(address(cDai)).toUint256();
        uint256 initCDaiUnitsUnderlying = initCDaiUnits.preciseDiv(cDaiExchangeRate);

        {
            address[] memory transformComponents = new address[](1);
            transformComponents[0] = address(cDai);
            bytes[] memory untransformData = new bytes[](1);
            untransformData[0] = bytes("");

            try ipRebalanceExtension.batchUntransform(transformComponents, untransformData) {} catch {}
        }

        uint256 initYDaiUnits = setToken.getDefaultPositionRealUnit(address(yDai)).toUint256();
        uint256 initYDaiUnitsUnderlying = initYDaiUnits.preciseDiv(yDaiExchangeRate);

        {
            address[] memory transformComponents = new address[](1);
            transformComponents[0] = address(yDai);
            bytes[] memory untransformData = new bytes[](1);
            untransformData[0] = bytes("");

            try ipRebalanceExtension.batchUntransform(transformComponents, untransformData) {} catch {}
        }

        uint256 finalCDaiUnits = setToken.getDefaultPositionRealUnit(address(cDai)).toUint256();
        uint256 finalCDaiUnitsUnderlying = finalCDaiUnits.preciseDiv(cDaiExchangeRate);

        uint256 expectedCDaiUnitsUnderlying = targetCDaiUnitsUnderlying < initCDaiUnitsUnderlying ?
            targetCDaiUnitsUnderlying :
            initCDaiUnitsUnderlying;
        
        assertTrue(isApproxEqual(finalCDaiUnitsUnderlying, expectedCDaiUnitsUnderlying));

        uint256 finalYDaiUnits = setToken.getDefaultPositionRealUnit(address(yDai)).toUint256();
        uint256 finalYDaiUnitsUnderlying = finalYDaiUnits.preciseDiv(yDaiExchangeRate);

        uint256 expectedYDaiUnitsUnderlying = targetYDaiUnitsUnderlying < initYDaiUnitsUnderlying ?
            targetYDaiUnitsUnderlying :
            initYDaiUnitsUnderlying;
        
        assertTrue(isApproxEqual(finalYDaiUnitsUnderlying, expectedYDaiUnitsUnderlying));
    }

    function test_transform(uint96 targetDaiUnits, uint96 targetCDaiUnitsUnderlying, uint96 targetYDaiUnitsUnderlying) public {

        // setup
        uint256[] memory units = new uint256[](3);
        units[0] = targetDaiUnits;
        units[1] = targetCDaiUnitsUnderlying;
        units[2] = targetYDaiUnitsUnderlying;

        ipRebalanceExtension.startIPRebalance(components, units);

        for (uint256 i = 0; i < components.length; i++) {
            address[] memory transformComponents = new address[](1);
            transformComponents[0] = address(components[i]);
            bytes[] memory untransformData = new bytes[](1);
            untransformData[0] = bytes("");

            try ipRebalanceExtension.batchUntransform(transformComponents, untransformData) {} catch {}
        }

        ipRebalanceExtension.startTrades();
        ipRebalanceExtension.setTradesComplete();

        // do transforms
        {
            address[] memory transformComponents = new address[](1);
            transformComponents[0] = address(cDai);
            bytes[] memory transformData = new bytes[](1);
            transformData[0] = bytes("");

            try ipRebalanceExtension.batchTransform(transformComponents, transformData) {} catch {}
        }


        {
            address[] memory transformComponents = new address[](1);
            transformComponents[0] = address(yDai);
            bytes[] memory transformData = new bytes[](1);
            transformData[0] = bytes("");

            try ipRebalanceExtension.batchTransform(transformComponents, transformData) {} catch {}
        }

        // checks

        uint256 daiUnits = setToken.getDefaultPositionRealUnit(address(dai)).toUint256();

        uint256 finalCDaiUnits = setToken.getDefaultPositionRealUnit(address(cDai)).toUint256();
        uint256 finalCDaiUnitsUnderlying = finalCDaiUnits.preciseDiv(cDaiExchangeRate);
        assertTrue(isApproxEqual(finalCDaiUnitsUnderlying, targetCDaiUnitsUnderlying) || daiUnits == 0);

        uint256 finalYDaiUnits = setToken.getDefaultPositionRealUnit(address(yDai)).toUint256();
        uint256 finalYDaiUnitsUnderlying = finalYDaiUnits.preciseDiv(yDaiExchangeRate);
        assertTrue(isApproxEqual(finalYDaiUnitsUnderlying, targetYDaiUnitsUnderlying) || daiUnits == 0);
    }

    function test_transformRemaining(
        uint96 targetCDaiUnitsUnderlying,
        uint96 targetYDaiUnitsUnderlying,
        uint256 componentIndexSeed
    ) 
        public 
    {
        // setup
        uint256[] memory units = new uint256[](3);
        units[0] = 0;   // target dai units must be 0
        units[1] = targetCDaiUnitsUnderlying;
        units[2] = targetYDaiUnitsUnderlying;

        ipRebalanceExtension.startIPRebalance(components, units);

        for (uint256 i = 0; i < components.length; i++) {
            address[] memory transformComponents = new address[](1);
            transformComponents[0] = address(components[i]);
            bytes[] memory untransformData = new bytes[](1);
            untransformData[0] = bytes("");

            try ipRebalanceExtension.batchUntransform(transformComponents, untransformData) {} catch {}
        }

        ipRebalanceExtension.startTrades();
        ipRebalanceExtension.setTradesComplete();

        // perform transfromRamining

        uint256 componentIndex = componentIndexSeed % components.length;
        try ipRebalanceExtension.transformRemaining(components[componentIndex], bytes("")) {} catch {}

        (address underlying, ) = ipRebalanceExtension.transformComponentInfo(components[componentIndex]);
        uint256 finalUnderlyingUnits = setToken.getDefaultPositionRealUnit(underlying).toUint256();

        assertEq(finalUnderlyingUnits, 0);
    }

    function test_startTrades(uint96 targetDaiUnits, uint96 targetCDaiUnitsUnderlying, uint96 targetYDaiUnitsUnderlying) public {

        uint256[] memory units = new uint256[](3);
        units[0] = targetDaiUnits;
        units[1] = targetCDaiUnitsUnderlying;
        units[2] = targetYDaiUnitsUnderlying;

        ipRebalanceExtension.startIPRebalance(components, units);

        for (uint256 i = 0; i < components.length; i++) {
            address[] memory transformComponents = new address[](1);
            transformComponents[0] = address(components[i]);
            bytes[] memory untransformData = new bytes[](1);
            untransformData[0] = bytes("");

            try ipRebalanceExtension.batchUntransform(transformComponents, untransformData) {} catch {}
        }

        ipRebalanceExtension.startTrades();

        uint256 currentYDaiUnderlying = setToken.getDefaultPositionRealUnit(address(yDai)).toUint256().preciseDiv(yDaiExchangeRate);
        uint256 currentCDaiUnderlying = setToken.getDefaultPositionRealUnit(address(cDai)).toUint256().preciseDiv(cDaiExchangeRate);

        uint256 targetSum = uint256(targetDaiUnits) + uint256(targetCDaiUnitsUnderlying) + uint256(targetYDaiUnitsUnderlying);
        uint256 currentSum = currentYDaiUnderlying + currentCDaiUnderlying;

        uint256 daiTarget = targetSum > currentSum ? targetSum - currentSum : 0;
        (uint256 actualDaiTarget, , , , , ) = setFixture.generalIndexModule().executionInfo(ISetTokenSet(address(setToken)), dai);

        assertEq(actualDaiTarget, daiTarget);
    }

    function isApproxEqual(uint256 a, uint256 b) internal returns (bool) {
        bool passed;
        if (b < 2) {
            passed = a <= 2;
        } else if (b > uint(-1) - 2) {
            passed = a >= uint(-1) - 2;
        } else {
            passed = a <= b + 2 && a >= b - 2;
        }
        if (!passed) {
            log_named_uint("a", a);
            log_named_uint("b", b);
        }
        return passed;
    }
}
