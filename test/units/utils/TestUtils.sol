// SPDX-FileCopyrightText: 2025 IEXEC BLOCKCHAIN TECH <contact@iex.ec>
// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.22;

import {OptionsBuilder} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import {MessagingFee, SendParam} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import {IOFT} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import {CreateX} from "@createx/contracts/CreateX.sol";
import {UUPSProxyDeployer} from "../../../script/lib/UUPSProxyDeployer.sol";
import {RLCAdapter} from "../../../src/RLCAdapter.sol";
import {RLCOFTMock} from "../mocks/RLCOFTMock.sol";
import {RLCMock} from "../mocks/RLCMock.sol";
import {RLCOFT} from "../../../src/RLCOFT.sol";
import {UpgradeUtils} from "../../../script/lib/UpgradeUtils.sol";

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

    /**
     * @notice Prepare send parameters and quote fee without executing
     * @param oft The OFT contract to send from
     * @param to The destination address (as bytes32)
     * @param amount The amount to send
     * @param dstEid The destination endpoint ID
     * @return sendParam The prepared send parameters
     * @return fee The quoted messaging fee
     */
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

library TestUpgradeUtils {
    /**
     * @notice Helper function for OFT test upgrades with mock contracts
     * @param proxyAddress Address of the proxy to upgrade
     * @param contractName Name of the new implementation contract
     * @param lzEndpoint LayerZero endpoint address
     * @param newStateVariable Value for V2 initialization
     * @return newImplementationAddress Address of the new implementation
     */
    function upgradeOFTForTesting(
        address proxyAddress,
        string memory contractName,
        address lzEndpoint,
        uint256 newStateVariable
    ) internal returns (address) {
        UpgradeUtils.UpgradeParams memory params = UpgradeUtils.UpgradeParams({
            proxyAddress: proxyAddress,
            contractName: contractName,
            rlcToken: address(0), // Not used for OFT
            lzEndpoint: lzEndpoint,
            contractType: UpgradeUtils.ContractType.OFT,
            newStateVariable: newStateVariable,
            skipChecks: true, // Allow for testing with mocks
            validateOnly: false
        });

        return UpgradeUtils.executeUpgradeOFT(params);
    }

    /**
     * @notice Helper function for Adapter test upgrades with mock contracts
     * @param proxyAddress Address of the proxy to upgrade
     * @param contractName Name of the new implementation contract
     * @param lzEndpoint LayerZero endpoint address
     * @param newStateVariable Value for V2 initialization
     * @return newImplementationAddress Address of the new implementation
     */
    function upgradeAdapterForTesting(
        address proxyAddress,
        string memory contractName,
        address lzEndpoint,
        address rlcToken,
        uint256 newStateVariable
    ) internal returns (address) {
        UpgradeUtils.UpgradeParams memory params = UpgradeUtils.UpgradeParams({
            proxyAddress: proxyAddress,
            contractName: contractName,
            lzEndpoint: lzEndpoint,
            rlcToken: rlcToken,
            contractType: UpgradeUtils.ContractType.ADAPTER,
            newStateVariable: newStateVariable,
            skipChecks: true, // Allow for testing with mocks
            validateOnly: false
        });

        return UpgradeUtils.executeUpgradeAdapter(params);
    }

    /**
     * @notice Helper for validating upgrades in tests
     * @param contractName Name of the contract to validate
     * @param lzEndpoint LayerZero endpoint address
     * @param contractType Type of contract being validated
     */
    function validateUpgradeForTesting(
        string memory contractName,
        address lzEndpoint,
        UpgradeUtils.ContractType contractType
    ) internal {
        UpgradeUtils.UpgradeParams memory params = UpgradeUtils.UpgradeParams({
            proxyAddress: address(0), // Not needed for validation
            contractName: contractName,
            rlcToken: address(0), // Not used for OFT
            lzEndpoint: lzEndpoint,
            contractType: contractType,
            newStateVariable: 0, // Not needed for validation
            skipChecks: true,
            validateOnly: true
        });

        UpgradeUtils.validateUpgrade(params);
    }
}
