// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {Deploy as RLCOFTDeploy, Configure as RLCOFTConfigure} from "../../script/RLCOFT.s.sol";
import {RLCOFT} from "../../src/RLCOFT.sol";

contract RLCOFTScriptTest is Test {
    RLCOFT public rlcOft;

    address owner = makeAddr("OWNER_ADDRESS");
    address pauser = makeAddr("PAUSER_ADDRESS");

    function setUp() public {
        vm.createSelectFork("https://arbitrum-sepolia-rpc.publicnode.com"); // use public node

        vm.setEnv("RLC_OFT_TOKEN_NAME", "RLC OFT Token");
        vm.setEnv("RLC_TOKEN_SYMBOL", "RLC");
        vm.setEnv("LAYER_ZERO_ARBITRUM_SEPOLIA_ENDPOINT_ADDRESS", "0x6EDCE65403992e310A62460808c4b910D972f10f");
        vm.setEnv("OWNER_ADDRESS", vm.toString(owner));
        vm.setEnv("PAUSER_ADDRESS", vm.toString(pauser));

        rlcOft = RLCOFT(new RLCOFTDeploy().run());
    }

    /**
     * Deployment
     */
    function test_CheckDeployment() public view {
        assertEq(rlcOft.owner(), vm.envAddress("OWNER_ADDRESS"));
        assertEq(rlcOft.token(), address(rlcOft));
    }
}
