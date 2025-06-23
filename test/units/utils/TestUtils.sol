// SPDX-FileCopyrightText: 2025 IEXEC BLOCKCHAIN TECH <contact@iex.ec>
// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.22;

import {OptionsBuilder} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import {MessagingFee, SendParam} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import {IOFT} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import {CreateX} from "@createx/contracts/CreateX.sol";
import {UUPSProxyDeployer} from "../../../script/lib/UUPSProxyDeployer.sol";
import {RLCMock} from "../mocks/RLCMock.sol";
import {IexecLayerZeroBridge} from "../../../src/bridges/layerZero/IexecLayerZeroBridge.sol";
import {LiquidityUnifier} from "../../../src/LiquidityUnifier.sol";

library TestUtils {
    using OptionsBuilder for bytes;

    function setupDeployment(
        string memory name,
        string memory symbol,
        address lzEndpointAdapter,
        address lzEndpointBridge,
        address admin,
        address pauser
    )
        internal
        returns (
            IexecLayerZeroBridge iexecLayerZeroBridgeChainA,
            IexecLayerZeroBridge iexecLayerZeroBridgeChainB,
            RLCMock rlcToken,
            RLCMock rlcCrosschainToken
        )
    {
        address createXFactory = address(new CreateX());

        // Deploy RLC token mock for Ethereum
        rlcToken = new RLCMock(name, symbol);

        // salt for createX
        bytes32 salt = keccak256("salt");

        // Deploy Liquidity Unifier
        LiquidityUnifier liquidityUnifier = LiquidityUnifier(
            UUPSProxyDeployer.deployUUPSProxyWithCreateX(
                "LiquidityUnifier",
                abi.encode(rlcToken),
                abi.encodeWithSelector(LiquidityUnifier.initialize.selector, admin, admin), //TODO: fix IexecLayerZeroBridge contract to make distinction between admin and upgrader & add a new param to this function
                createXFactory,
                salt
            )
        );

        // Deploy IexecLayerZeroBridgeAdapter
        iexecLayerZeroBridgeChainA = IexecLayerZeroBridge(
            UUPSProxyDeployer.deployUUPSProxyWithCreateX(
                "IexecLayerZeroBridge",
                abi.encode(liquidityUnifier, lzEndpointAdapter),
                abi.encodeWithSelector(IexecLayerZeroBridge.initialize.selector, admin, pauser),
                createXFactory,
                salt
            )
        );

        // Deploy RLC token mock for Arbitrum
        rlcCrosschainToken = new RLCMock(name, symbol);

        // Deploy IexecLayerZeroBridge
        iexecLayerZeroBridgeChainB = IexecLayerZeroBridge(
            UUPSProxyDeployer.deployUUPSProxyWithCreateX(
                "IexecLayerZeroBridge",
                abi.encode(rlcCrosschainToken, lzEndpointBridge),
                abi.encodeWithSelector(IexecLayerZeroBridge.initialize.selector, admin, pauser),
                createXFactory,
                salt
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
