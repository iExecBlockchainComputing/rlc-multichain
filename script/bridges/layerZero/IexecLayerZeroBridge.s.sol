// SPDX-FileCopyrightText: 2025 IEXEC BLOCKCHAIN TECH <contact@iex.ec>
// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.22;

import {Script} from "forge-std/Script.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {EnforcedOptionParam} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OAppOptionsType3.sol";
import {OptionsBuilder} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import {ConfigLib} from "./../../lib/ConfigLib.sol";
import {IexecLayerZeroBridge} from "../../../src/bridges/layerZero/IexecLayerZeroBridge.sol";
import {RLCLiquidityUnifier} from "../../../src/RLCLiquidityUnifier.sol";
import {RLCCrosschainToken} from "../../../src/RLCCrosschainToken.sol";
import {UUPSProxyDeployer} from "../../lib/UUPSProxyDeployer.sol";
import {UpgradeUtils} from "../../lib/UpgradeUtils.sol";

contract Deploy is Script {
    /**
     * Reads configuration from config file and deploys IexecLayerZeroBridge contract.
     * @return address of the deployed IexecLayerZeroBridge proxy contract.
     */
    function run() external returns (address) {
        string memory chain = vm.envString("CHAIN");
        ConfigLib.CommonConfigParams memory params = ConfigLib.readCommonConfig(chain);

        vm.startBroadcast();
        address iexecLayerZeroBridgeProxy = deploy(
            params.approvalRequired,
            params.approvalRequired ? params.rlcLiquidityUnifierAddress : params.rlcCrosschainTokenAddress,
            params.lzEndpoint,
            params.initialAdmin,
            params.initialUpgrader,
            params.initialPauser,
            params.createxFactory,
            params.iexecLayerZeroBridgeCreatexSalt
        );

        vm.stopBroadcast();
        ConfigLib.updateConfigAddress(chain, "iexecLayerZeroBridgeAddress", iexecLayerZeroBridgeProxy);
        return iexecLayerZeroBridgeProxy;
    }

    function deploy(
        bool approvalRequired,
        address bridgeableToken,
        address lzEndpoint,
        address initialAdmin,
        address initialUpgrader,
        address initialPauser,
        address createxFactory,
        bytes32 createxSalt
    ) public returns (address) {
        bytes memory constructorData = abi.encode(approvalRequired, bridgeableToken, lzEndpoint);
        bytes memory initializeData = abi.encodeWithSelector(
            IexecLayerZeroBridge.initialize.selector, initialAdmin, initialUpgrader, initialPauser
        );
        return UUPSProxyDeployer.deployUsingCreateX(
            "IexecLayerZeroBridge", constructorData, initializeData, createxFactory, createxSalt
        );
    }
}

contract Configure is Script {
    using OptionsBuilder for bytes;

    function run() external {
        string memory sourceChain = vm.envString("SOURCE_CHAIN");
        string memory targetChain = vm.envString("TARGET_CHAIN");
        ConfigLib.CommonConfigParams memory sourceParams = ConfigLib.readCommonConfig(sourceChain);
        ConfigLib.CommonConfigParams memory targetParams = ConfigLib.readCommonConfig(targetChain);
        IexecLayerZeroBridge sourceBridge = IexecLayerZeroBridge(sourceParams.iexecLayerZeroBridgeAddress);
        vm.startBroadcast();
        sourceBridge.setPeer(
            targetParams.lzChainId, bytes32(uint256(uint160(targetParams.iexecLayerZeroBridgeAddress)))
        );
        EnforcedOptionParam[] memory enforcedOptions = new EnforcedOptionParam[](1);
        bytes memory _extraOptions = OptionsBuilder.newOptions().addExecutorLzReceiveOption(70_000, 0); // 70_000 gas limit for the receiving executor and 0 for the executor's value
        enforcedOptions[0] = EnforcedOptionParam(targetParams.lzChainId, 2, _extraOptions);
        sourceBridge.setEnforcedOptions(enforcedOptions);
        // Authorize bridge in the relevant contract.
        if (sourceParams.approvalRequired) {
            RLCLiquidityUnifier rlcLiquidityUnifier = RLCLiquidityUnifier(sourceParams.rlcLiquidityUnifierAddress);
            bytes32 bridgeTokenRoleId = rlcLiquidityUnifier.TOKEN_BRIDGE_ROLE();
            rlcLiquidityUnifier.grantRole(bridgeTokenRoleId, address(sourceBridge));
        } else {
            RLCCrosschainToken rlcCrosschainToken = RLCCrosschainToken(sourceParams.rlcCrosschainTokenAddress);
            bytes32 bridgeTokenRoleId = rlcCrosschainToken.TOKEN_BRIDGE_ROLE();
            rlcCrosschainToken.grantRole(bridgeTokenRoleId, address(sourceBridge));
        }

        vm.stopBroadcast();
    }
}

contract Upgrade is Script {
    function run() external {
        string memory chain = vm.envString("CHAIN");
        ConfigLib.CommonConfigParams memory commonParams = ConfigLib.readCommonConfig(chain);

        // For testing purpose
        uint256 newStateVariable = 1000000 * 10 ** 9;
        address bridgeableToken = commonParams.approvalRequired
            ? commonParams.rlcLiquidityUnifierAddress
            : commonParams.rlcCrosschainTokenAddress;
        vm.startBroadcast();
        UpgradeUtils.UpgradeParams memory params = UpgradeUtils.UpgradeParams({
            proxyAddress: commonParams.iexecLayerZeroBridgeAddress,
            constructorData: abi.encode(commonParams.approvalRequired, bridgeableToken, commonParams.lzEndpoint),
            contractName: "IexecLayerZeroBridgeV2Mock.sol:IexecLayerZeroBridgeV2", // Would be production contract in real deployment
            newStateVariable: newStateVariable
        });
        UpgradeUtils.executeUpgrade(params);
        vm.stopBroadcast();
    }
}
