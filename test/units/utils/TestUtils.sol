// SPDX-FileCopyrightText: 2025 IEXEC BLOCKCHAIN TECH <contact@iex.ec>
// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.22;

import {OptionsBuilder} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import {MessagingFee, SendParam} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import {IOFT} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import {CreateX} from "@createx/contracts/CreateX.sol";
import {UUPSProxyDeployer} from "../../../script/lib/UUPSProxyDeployer.sol";
import {RLCAdapter} from "../../../src/RLCAdapter.sol";
import {RLCMock} from "../mocks/RLCMock.sol";
import {IexecLayerZeroBridge} from "../../../src/IexecLayerZeroBridge.sol";
import {UpgradeUtils} from "../../../script/lib/UpgradeUtils.sol";

library TestUtils {
    using OptionsBuilder for bytes;

    function setupDeployment(
        string memory name,
        string memory symbol,
        address lzEndpointAdapter,
        address lzEndpointBridge,
        address owner,
        address pauser
    )
        internal
        returns (
            RLCAdapter rlcAdapter,
            IexecLayerZeroBridge iexecLayerZeroBridge,
            RLCMock rlcToken,
            RLCMock rlcCrosschainToken
        )
    {
        address createXFactory = address(new CreateX());

        // Deploy RLC token mock for Ethereum
        rlcToken = new RLCMock(name, symbol);

        // Deploy RLCAdapter
        bytes32 salt = keccak256("RLCAdapter_SALT");
        rlcAdapter = RLCAdapter(
            UUPSProxyDeployer.deployUUPSProxyWithCreateX(
                "RLCAdapter",
                abi.encode(rlcToken, lzEndpointAdapter),
                abi.encodeWithSelector(RLCAdapter.initialize.selector, owner, pauser),
                createXFactory,
                salt
            )
        );

        // Deploy RLC token mock for Arbitrum
        rlcCrosschainToken = new RLCMock(name, symbol);

        // Deploy IexecLayerZeroBridge
        iexecLayerZeroBridge = IexecLayerZeroBridge(
            UUPSProxyDeployer.deployUUPSProxyWithCreateX(
                "IexecLayerZeroBridge",
                abi.encode(rlcCrosschainToken, lzEndpointBridge),
                abi.encodeWithSelector(IexecLayerZeroBridge.initialize.selector, owner, pauser),
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
