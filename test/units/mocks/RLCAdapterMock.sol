// SPDX-FileCopyrightText: 2025 IEXEC BLOCKCHAIN TECH <contact@iex.ec>
// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.22;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {RLCAdapter} from "../../../src/RLCAdapter.sol";

contract Deploy is Test {
    function run(address rlcToken, address lzEndpoint, address owner, address pauser) external returns (address) {
        // Deploy the RLCAdapter contract
        RLCAdapter rlcAdapterImplementation = new RLCAdapter(rlcToken, lzEndpoint);
        console.log("RLCAdapter implementation deployed at:", address(rlcAdapterImplementation));

        // Deploy the proxy contract
        address rlcAdapterProxyAddress = address(
            new ERC1967Proxy(
                address(rlcAdapterImplementation),
                abi.encodeWithSelector(rlcAdapterImplementation.initialize.selector, owner, pauser)
            )
        );
        console.log("RLCAdapter proxy deployed at:", rlcAdapterProxyAddress);
        return rlcAdapterProxyAddress;
    }
}
