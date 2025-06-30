// SPDX-FileCopyrightText: 2025 IEXEC BLOCKCHAIN TECH <contact@iex.ec>
// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.22;

import {CreateX} from "@createx/contracts/CreateX.sol";
import {OptionsBuilder} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import {MessagingFee, SendParam} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import {IOFT} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import {UUPSProxyDeployer} from "../../../script/lib/UUPSProxyDeployer.sol";
import {RLCMock} from "../mocks/RLCMock.sol";
import {IexecLayerZeroBridge} from "../../../src/bridges/layerZero/IexecLayerZeroBridge.sol";
import {RLCLiquidityUnifier} from "../../../src/RLCLiquidityUnifier.sol";
import {RLCCrosschainToken} from "../../../src/RLCCrosschainToken.sol";
import {Deploy as RLCCrosschainTokenDeployScript} from "../../../script/RLCCrosschainToken.s.sol";

library TestUtils {
    using OptionsBuilder for bytes;

    // TODO declare name and symbol inside the function.
    function setupDeployment(
        string memory name,
        string memory symbol,
        address lzEndpointAdapter,
        address lzEndpointBridge,
        address initialAdmin,
        address initialUpgrader,
        address initialPauser
    )
        internal
        returns (
            IexecLayerZeroBridge iexecLayerZeroBridgeChainA,
            IexecLayerZeroBridge iexecLayerZeroBridgeChainB,
            RLCMock rlcToken,
            RLCCrosschainToken rlcCrosschainToken,
            RLCLiquidityUnifier rlcLiquidityUnifier
        )
    {
        address createXFactory = address(new CreateX());

        // Deploy RLC token mock for L1
        rlcToken = new RLCMock();

        // salt for createX
        bytes32 salt = keccak256("salt");

        // Deploy Liquidity Unifier
        rlcLiquidityUnifier = RLCLiquidityUnifier(
            UUPSProxyDeployer.deployUUPSProxyWithCreateX(
                "RLCLiquidityUnifier",
                abi.encode(rlcToken),
                abi.encodeWithSelector(RLCLiquidityUnifier.initialize.selector, initialAdmin, initialUpgrader),
                createXFactory,
                salt
            )
        );

        // Deploy IexecLayerZeroBridgeAdapter
        iexecLayerZeroBridgeChainA = IexecLayerZeroBridge(
            UUPSProxyDeployer.deployUUPSProxyWithCreateX(
                "IexecLayerZeroBridge",
                abi.encode(true, rlcLiquidityUnifier, lzEndpointAdapter),
                abi.encodeWithSelector(
                    IexecLayerZeroBridge.initialize.selector, initialAdmin, initialUpgrader, initialPauser
                ),
                createXFactory,
                salt
            )
        );

        // Deploy RLC Crosschain token (for L2)
        rlcCrosschainToken = RLCCrosschainToken(
            new RLCCrosschainTokenDeployScript().deploy(
                name, symbol, initialAdmin, initialUpgrader, createXFactory, salt
            )
        );
        // Deploy IexecLayerZeroBridge
        iexecLayerZeroBridgeChainB = IexecLayerZeroBridge(
            UUPSProxyDeployer.deployUUPSProxyWithCreateX(
                "IexecLayerZeroBridge",
                abi.encode(false, rlcCrosschainToken, lzEndpointBridge),
                abi.encodeWithSelector(
                    IexecLayerZeroBridge.initialize.selector, initialAdmin, initialUpgrader, initialPauser
                ),
                createXFactory,
                salt
            )
        );
        // TODO see if it's possible to authorize the bridge here.
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
