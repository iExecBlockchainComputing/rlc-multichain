// SPDX-FileCopyrightText: 2025 IEXEC BLOCKCHAIN TECH <contact@iex.ec>
// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.22;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";

/**
 * @title GetConfigInfo
 * @dev Script to extract configuration information and proxy implementation addresses.
 * Replaces bash scripts with type-safe Solidity implementation.
 *
 * Usage examples:
 * - Get config field: forge script script/GetConfigInfo.s.sol --sig "getConfigField(string,string)" "sepolia" "rlcCrosschainTokenAddress"
 * - Get implementation: forge script script/GetConfigInfo.s.sol --sig "getImplementationAddress(string,string)" "sepolia" "rlcCrosschainTokenAddress"
 */
contract GetConfigInfo is Script {
    using stdJson for string;
    /**
     * @dev Get a configuration field value for a specific chain
     * @param field The field name to retrieve
     */

    function getConfigField(string calldata field) external view {
        string memory config = vm.readFile("config/config.json");
        address value = config.readAddress(field);
        console.log(value);
    }

    /**
     * @dev Get the implementation address of a proxy contract
     * @param proxyField The config field containing the proxy address
     */
    function getImplementationAddress(string calldata proxyField) external view {
        string memory config = vm.readFile("config/config.json");
        address proxyAddress = config.readAddress(proxyField);
        if (proxyAddress == address(0)) {
            console.log("Error: Proxy address is zero for field '%s'", proxyField);
            revert("Zero proxy address");
        }
        // Get implementation address using OpenZeppelin's Upgrades library
        address impl = Upgrades.getImplementationAddress(proxyAddress);
        console.log(impl);
    }
}
