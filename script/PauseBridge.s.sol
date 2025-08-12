// SPDX-FileCopyrightText: 2025 IEXEC BLOCKCHAIN TECH <contact@iex.ec>
// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.22;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {ConfigLib} from "./lib/ConfigLib.sol";
import {IexecLayerZeroBridge} from "../src/bridges/layerZero/IexecLayerZeroBridge.sol";

/**
 * Levels of pause:
 * Level 1 (Complete Pause): Blocks ALL bridge operations (inbound and outbound)
 * Level 2 (Outbound Only): Blocks only outbound transfers, allows users to receive/withdraw
 */

/**
 * @title PauseBridge
 * @dev Script to pause bridge operations on the current chain.
 */
contract PauseBridge is Script {
    /**
     * @notice Pauses all bridge operations (Level 1 - Complete Pause)
     * @dev This function blocks both inbound and outbound transfers
     * Use this for critical security incidents
     */
    function run() external virtual {
        string memory chain = vm.envString("CHAIN");
        console.log("Pausing ALL bridge operations on chain:", chain);

        ConfigLib.CommonConfigParams memory params = ConfigLib.readCommonConfig(chain);
        vm.startBroadcast();
        pauseBridge(params);
        vm.stopBroadcast();
    }

    /**
     * @notice Pauses the bridge operations
     * @param params The configuration parameters for the current chain
     */
    function pauseBridge(ConfigLib.CommonConfigParams memory params) public virtual {
        PauseBridgeValidation.validateBridgeAddress(params.iexecLayerZeroBridgeAddress);
        IexecLayerZeroBridge bridge = IexecLayerZeroBridge(params.iexecLayerZeroBridgeAddress);

        console.log("Executing complete pause on bridge at:", params.iexecLayerZeroBridgeAddress);
        bridge.pause();
        console.log("Bridge completely paused");
        console.log("Both inbound and outbound transfers are now blocked");
    }
}

/**
 * @title UnpauseBridge
 * @dev Script to unpause bridge operations on the current chain.
 * This restores all bridge functionality.
 */
contract UnpauseBridge is Script {
    /**
     * @notice Unpauses all bridge operations
     * @dev This function restores both inbound and outbound transfers
     */
    function run() external virtual {
        string memory chain = vm.envString("CHAIN");
        console.log("Unpausing ALL bridge operations on chain:", chain);

        ConfigLib.CommonConfigParams memory params = ConfigLib.readCommonConfig(chain);
        vm.startBroadcast();
        unpauseBridge(params);
        vm.stopBroadcast();
    }

    /**
     * @notice Unpauses the bridge operations
     * @param params The configuration parameters for the current chain
     */
    function unpauseBridge(ConfigLib.CommonConfigParams memory params) public virtual {
        PauseBridgeValidation.validateBridgeAddress(params.iexecLayerZeroBridgeAddress);
        IexecLayerZeroBridge bridge = IexecLayerZeroBridge(params.iexecLayerZeroBridgeAddress);

        console.log("Executing unpause on bridge at:", params.iexecLayerZeroBridgeAddress);
        bridge.unpause();
        console.log("Bridge unpaused");
        console.log("Both inbound and outbound transfers are now enabled");
    }
}

/**
 * @title PauseOutboundTransfers
 * @dev Script to pause only outbound transfers (Level 2 - Partial Pause)
 * This allows users to still receive funds and "exit" their positions while blocking new outbound transfers.
 */
contract PauseOutboundTransfers is Script {
    /**
     * @notice Pauses only outbound transfers (Level 2 - Partial Pause)
     * @dev This function blocks outbound transfers but allows inbound transfers
     * Use this for less critical issues when you want to allow user withdrawals
     */
    function run() external virtual {
        string memory chain = vm.envString("CHAIN");
        console.log("Pausing OUTBOUND transfers only on chain:", chain);

        ConfigLib.CommonConfigParams memory params = ConfigLib.readCommonConfig(chain);
        vm.startBroadcast();
        pauseOutboundTransfers(params);
        vm.stopBroadcast();
    }

    /**
     * @notice Pauses outbound transfers on the bridge
     * @param params The configuration parameters for the current chain
     */
    function pauseOutboundTransfers(ConfigLib.CommonConfigParams memory params) public virtual {
        PauseBridgeValidation.validateBridgeAddress(params.iexecLayerZeroBridgeAddress);
        IexecLayerZeroBridge bridge = IexecLayerZeroBridge(params.iexecLayerZeroBridgeAddress);

        console.log("Executing outbound transfer pause on bridge at:", params.iexecLayerZeroBridgeAddress);
        bridge.pauseOutboundTransfers();
        console.log("Outbound transfers paused");
        console.log("Outbound transfers are blocked, inbound transfers still work");
        console.log("Users can still receive funds and exit their positions");
    }
}

/**
 * @title UnpauseOutboundTransfers
 * @dev Script to unpause outbound transfers (restores send functionality)
 * This restores outbound transfer capability while maintaining inbound functionality.
 */
contract UnpauseOutboundTransfers is Script {
    /**
     * @notice Unpauses outbound transfers (restores send functionality)
     * @dev This function restores outbound transfer capability
     */
    function run() external virtual {
        string memory chain = vm.envString("CHAIN");
        console.log("Unpausing OUTBOUND transfers on chain:", chain);

        ConfigLib.CommonConfigParams memory params = ConfigLib.readCommonConfig(chain);
        vm.startBroadcast();
        unpauseOutboundTransfers(params);
        vm.stopBroadcast();
    }

    /**
     * @notice Unpauses outbound transfers on the bridge
     * @param params The configuration parameters for the current chain
     */
    function unpauseOutboundTransfers(ConfigLib.CommonConfigParams memory params) public virtual {
        PauseBridgeValidation.validateBridgeAddress(params.iexecLayerZeroBridgeAddress);
        IexecLayerZeroBridge bridge = IexecLayerZeroBridge(params.iexecLayerZeroBridgeAddress);

        console.log("Executing outbound transfer unpause on bridge at:", params.iexecLayerZeroBridgeAddress);
        bridge.unpauseOutboundTransfers();
        console.log("Outbound transfers unpaused");
        console.log("Both inbound and outbound transfers are now enabled");
    }
}

library PauseBridgeValidation {
    /**
     * @notice Validates that the bridge contract address is not zero
     * @param bridgeAddress The bridge contract address
     */
    function validateBridgeAddress(address bridgeAddress) internal pure {
        require(bridgeAddress != address(0), "Bridge address cannot be zero");
    }
}
