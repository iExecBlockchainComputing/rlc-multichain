// SPDX-FileCopyrightText: 2025 IEXEC BLOCKCHAIN TECH <contact@iex.ec>
// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.22;

import {StdConstants} from "forge-std/StdConstants.sol";
import {Vm} from "forge-std/Vm.sol";
import {CreateX} from "@createx/contracts/CreateX.sol";
import {OptionsBuilder} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import {MessagingFee, SendParam} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import {IOFT} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import {UUPSProxyDeployer} from "../../../script/lib/UUPSProxyDeployer.sol";
import {RLCMock} from "../mocks/RLCMock.sol";
import {IexecLayerZeroBridge} from "../../../src/bridges/layerZero/IexecLayerZeroBridge.sol";
import {RLCLiquidityUnifier} from "../../../src/RLCLiquidityUnifier.sol";
import {Deploy as RLCLiquidityUnifierDeployScript} from "../../../script/RLCLiquidityUnifier.s.sol";
import {RLCCrosschainToken} from "../../../src/RLCCrosschainToken.sol";
import {Deploy as RLCCrosschainTokenDeployScript} from "../../../script/RLCCrosschainToken.s.sol";

library TestUtils {
    using OptionsBuilder for bytes;

    Vm constant vm = StdConstants.VM;

    // Struct to hold deployment parameters and reduce stack depth
    struct DeploymentParams {
        string iexecLayerZeroBridgeContractName;
        address lzEndpointSource;
        address lzEndpointDestination;
        address initialAdmin;
        address initialUpgrader;
        address initialPauser;
    }

    // Struct to hold deployment results
    struct DeploymentResult {
        IexecLayerZeroBridge iexecLayerZeroBridgeWithApproval;
        IexecLayerZeroBridge iexecLayerZeroBridgeWithoutApproval;
        RLCMock rlcToken;
        RLCCrosschainToken rlcCrosschainToken;
        RLCLiquidityUnifier rlcLiquidityUnifier;
    }

    function setupDeployment(DeploymentParams memory params) public returns (DeploymentResult memory result) {
        string memory name = "iEx.ec Network Token";
        string memory symbol = "RLC";
        address createXFactory = address(new CreateX());
        bytes32 salt = keccak256("salt");
        // Deploy RLC token mock for L1
        result.rlcToken = new RLCMock();
        // Deploy Liquidity Unifier
        result.rlcLiquidityUnifier = _deployLiquidityUnifier(params, result.rlcToken, createXFactory, salt);
        // Deploy IexecLayerZeroBridge for Sepolia
        result.iexecLayerZeroBridgeWithApproval =
            _deployBridge(params, true, address(result.rlcLiquidityUnifier), createXFactory, salt);
        // Deploy RLC Crosschain token and Bridge for ChainX
        result.rlcCrosschainToken = _deployCrosschainToken(params, name, symbol, createXFactory, salt);
        result.iexecLayerZeroBridgeWithoutApproval =
            _deployBridge(params, false, address(result.rlcCrosschainToken), createXFactory, salt);
        // Label addresses for easier debugging.
        vm.label(params.initialAdmin, "Admin");
        vm.label(params.initialUpgrader, "Upgrader");
        vm.label(params.initialPauser, "Pauser");
        vm.label(params.lzEndpointSource, "lzEndpointSource");
        vm.label(params.lzEndpointDestination, "lzEndpointDestination");
        vm.label(address(result.rlcToken), "RLCMock");
        vm.label(address(result.rlcLiquidityUnifier), "RLCLiquidityUnifier");
        vm.label(address(result.rlcCrosschainToken), "RLCCrosschainToken");
        vm.label(address(result.iexecLayerZeroBridgeWithoutApproval), "IexecLayerZeroBridgeWithoutApproval");
        vm.label(address(result.iexecLayerZeroBridgeWithApproval), "IexecLayerZeroBridgeWithApproval");
    }

    function _deployLiquidityUnifier(
        DeploymentParams memory params,
        RLCMock rlcToken,
        address createXFactory,
        bytes32 salt
    ) private returns (RLCLiquidityUnifier) {
        return RLCLiquidityUnifier(
            new RLCLiquidityUnifierDeployScript().deploy(
                address(rlcToken), params.initialAdmin, params.initialUpgrader, createXFactory, salt
            )
        );
    }

    function _deployBridge(
        DeploymentParams memory params,
        bool approvalRequired,
        address bridgeableToken,
        address createXFactory,
        bytes32 salt
    ) private returns (IexecLayerZeroBridge) {
        // `new IexecLayerZeroBridgeDeployScript().deploy()` is not used here because
        // it deploys the contract `IexecLayerZeroBridge` by default, but in some tests
        // we want to deploy `IexecLayerZeroBridgeHarness`.
        return IexecLayerZeroBridge(
            UUPSProxyDeployer.deployUsingCreateX(
                params.iexecLayerZeroBridgeContractName,
                abi.encode(
                    approvalRequired,
                    bridgeableToken,
                    approvalRequired ? params.lzEndpointSource : params.lzEndpointDestination
                ),
                abi.encodeWithSelector(
                    IexecLayerZeroBridge.initialize.selector,
                    params.initialAdmin,
                    params.initialUpgrader,
                    params.initialPauser
                ),
                createXFactory,
                salt
            )
        );
    }

    function _deployCrosschainToken(
        DeploymentParams memory params,
        string memory name,
        string memory symbol,
        address createXFactory,
        bytes32 salt
    ) private returns (RLCCrosschainToken) {
        return RLCCrosschainToken(
            new RLCCrosschainTokenDeployScript().deploy(
                name, symbol, params.initialAdmin, params.initialUpgrader, createXFactory, salt
            )
        );
    }

    /**
     * @notice Prepare send parameters and quote fee without executing
     * @param layerZeroContract The LayerZero contract that respect IOFT interface to send from
     * @param to The destination address (as bytes32)
     * @param amount The amount to send
     * @param dstEid The destination endpoint ID
     * @return sendParam The prepared send parameters
     * @return fee The quoted messaging fee
     */
    function prepareSend(IOFT layerZeroContract, bytes32 to, uint256 amount, uint32 dstEid)
        internal
        view
        returns (SendParam memory sendParam, MessagingFee memory fee)
    {
        bytes memory options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(200000, 0);
        sendParam = SendParam({
            dstEid: dstEid,
            to: to,
            amountLD: amount,
            minAmountLD: amount,
            extraOptions: options,
            composeMsg: "",
            oftCmd: ""
        });
        fee = layerZeroContract.quoteSend(sendParam, false);
    }
}
