// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Deploy as RLCAdapterDeploy, Configure as RLCAdapterConfigure} from "../script/RLCAdapter.s.sol";
import {RLCAdapter} from "../src/RLCAdapter.sol";
import {RLCAdapterTestSetup} from "./utils/RLCAdapterTestSetup.sol";

contract RLCAdapterScriptTest is RLCAdapterTestSetup {
    RLCAdapter public rlcAdapter;

    function setUp() public {
        rlcAdapter = RLCAdapter(_forkSepoliaAndDeploy());
    }

    /**
     * Deployment
     */
    function test_CheckDeployment() public view {
        assertEq(rlcAdapter.owner(), vm.envAddress("OWNER_ADDRESS"));
        assertEq(rlcAdapter.token(), vm.envAddress("RLC_SEPOLIA_ADDRESS"));
        // TODO check roles
    }
}
