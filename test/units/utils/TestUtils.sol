// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {OptionsBuilder} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import {MessagingFee, SendParam} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import {IOFT} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";

library TestUtils {
    using OptionsBuilder for bytes;

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
