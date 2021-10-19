// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.6.10;

import { AirdropModule } from "setprotocol/contracts/protocol/modules/AirdropModule.sol";
import { Controller } from "setprotocol/contracts/protocol/Controller.sol";
import { GeneralIndexModule } from "setprotocol/contracts/protocol/modules/GeneralIndexModule.sol";
import { IntegrationRegistry } from "setprotocol/contracts/protocol/IntegrationRegistry.sol";
import { BasicIssuanceModule } from "setprotocol/contracts/protocol/modules/BasicIssuanceModule.sol";
import { SetTokenCreator } from "setprotocol/contracts/protocol/SetTokenCreator.sol";
import { WrapModuleV2 } from "setprotocol/contracts/protocol/modules/WrapModuleV2.sol";

import { WETH9 } from "./WETH9.sol";

import { IController } from "setprotocol/contracts/interfaces/IController.sol";
import { IWETH } from "setprotocol/contracts/interfaces/external/IWETH.sol";

contract SetFixture {

    Controller public controller;
    IntegrationRegistry public integrationRegistry;
    SetTokenCreator public setTokenCreator;

    AirdropModule public airdropModule;
    BasicIssuanceModule public basicIssuanceModule;
    GeneralIndexModule public generalIndexModule;
    WrapModuleV2 public wrapModuleV2;

    WETH9 public weth;

    constructor() public {
        weth = new WETH9();
        controller = new Controller(msg.sender);

        IWETH wethInterface = IWETH(address(weth));
        IController controllerInterface = IController(address(controller));

        integrationRegistry = new IntegrationRegistry(controllerInterface);
        setTokenCreator = new SetTokenCreator(controllerInterface);
        airdropModule = new AirdropModule(controllerInterface);
        basicIssuanceModule = new BasicIssuanceModule(controllerInterface);
        generalIndexModule = new GeneralIndexModule(controllerInterface, wethInterface);
        wrapModuleV2 = new WrapModuleV2(controllerInterface, wethInterface);
    }
}