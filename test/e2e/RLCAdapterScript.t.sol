// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {Deploy as RLCAdapterDeploy, Configure as RLCAdapterConfigure} from "../../script/RLCAdapter.s.sol";
import {RLCAdapter} from "../../src/RLCAdapter.sol";

contract RLCAdapterScriptTest is Test {
    RLCAdapter public rlcAdapter;

    address owner = makeAddr("OWNER_ADDRESS");
    address pauser = makeAddr("PAUSER_ADDRESS");

    function setUp() public {
        vm.createSelectFork("https://ethereum-sepolia-rpc.publicnode.com"); // use public node

        vm.setEnv("RLC_OFT_TOKEN_NAME", "RLC OFT Token");
        vm.setEnv("RLC_TOKEN_SYMBOL", "RLC");
        vm.setEnv("LAYER_ZERO_ARBITRUM_SEPOLIA_ENDPOINT_ADDRESS", "0x6EDCE65403992e310A62460808c4b910D972f10f");
        vm.setEnv("OWNER_ADDRESS", vm.toString(owner));
        vm.setEnv("PAUSER_ADDRESS", vm.toString(pauser));
        
        rlcAdapter = RLCAdapter(new RLCAdapterDeploy().run());
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
