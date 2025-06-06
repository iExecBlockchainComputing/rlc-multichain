// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {Vm} from "forge-std/Vm.sol";
import {StdConstants} from "forge-std/StdConstants.sol";
import {OptionsBuilder} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import {MessagingFee, SendParam} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import {IOFT} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import {CreateX} from "@createx/contracts/CreateX.sol";
import {UUPSProxyDeployer} from "../../../script/lib/UUPSProxyDeployer.sol";
import {RLCAdapter} from "../../../src/RLCAdapter.sol";
import {RLCOFTMock} from "../mocks/RLCOFTMock.sol";
import {RLCMock} from "../mocks/RLCMock.sol";
import {RLCOFT} from "../../../src/RLCOFT.sol";

library TestUtils {
    using OptionsBuilder for bytes;

    function setupDeployment(
        string memory name,
        string memory symbol,
        address lzEndpointAdapter,
        address lzEndpointOFT,
        address owner,
        address pauser
    ) internal returns (RLCAdapter rlcAdapter, RLCOFTMock rlcOftMock, RLCMock rlcToken) {
        address createXFactory = address(new CreateX());

        // Deploy RLC token mock
        rlcToken = new RLCMock(name, symbol);

        // Deploy RLCAdapter
        bytes32 salt = keccak256("RLCAdapter_SALT");
        bytes memory constructorDataRLCAdapter = abi.encode(rlcToken, lzEndpointAdapter);
        bytes memory initializeDataRLCAdapter = abi.encodeWithSelector(RLCAdapter.initialize.selector, owner, pauser);
        rlcAdapter = RLCAdapter(
            UUPSProxyDeployer.deployUUPSProxyWithCreateX(
                "RLCAdapter", constructorDataRLCAdapter, initializeDataRLCAdapter, createXFactory, salt
            )
        );

        // Deploy RLCOFTMock
        bytes memory constructorDataRLCOFT = abi.encode(lzEndpointOFT);
        bytes memory initializeDataRLCOFT =
            abi.encodeWithSelector(RLCOFT.initialize.selector, name, symbol, owner, pauser);
        rlcOftMock = RLCOFTMock(
            UUPSProxyDeployer.deployUUPSProxyWithCreateX(
                "RLCOFTMock", constructorDataRLCOFT, initializeDataRLCOFT, createXFactory, salt
            )
        );
    }

    /// @notice Prepare send parameters and quote fee without executing
    /// @param oft The OFT contract to send from
    /// @param to The destination address (as bytes32)
    /// @param amount The amount to send
    /// @param dstEid The destination endpoint ID
    /// @return sendParam The prepared send parameters
    /// @return fee The quoted messaging fee
    function prepareSend(IOFT oft, bytes32 to, uint256 amount, uint32 dstEid)
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
        fee = oft.quoteSend(sendParam, false);
    }
}
