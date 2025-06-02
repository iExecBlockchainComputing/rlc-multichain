// SPDX-FileCopyrightText: 2025 IEXEC BLOCKCHAIN TECH <contact@iex.ec>
// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.22;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {RLCAdapter} from "../../../src/RLCAdapter.sol";

contract RLCAdapterMock is RLCAdapter {
    constructor(address _token, address _lzEndpoint) RLCAdapter(_token, _lzEndpoint) {}
}

contract Deploy is Test {
    function run(address rlcToken, address lzEndpoint, address owner, address pauser) external returns (address) {
        // Deploy the RLCAdapter contract
        RLCAdapterMock rlcAdapterMockImplementation = new RLCAdapterMock(rlcToken, lzEndpoint);
        console.log("RLCAdapterMock implementation deployed at:", address(rlcAdapterMockImplementation));

        // Deploy the proxy contract
        address rlcAdapterProxyAddress = address(
            new ERC1967Proxy(
                address(rlcAdapterMockImplementation),
                abi.encodeWithSelector(rlcAdapterMockImplementation.initialize.selector, owner, pauser)
            )
        );
        console.log("RLCAdapter proxy deployed at:", rlcAdapterProxyAddress);
        return rlcAdapterProxyAddress;
    }
}
