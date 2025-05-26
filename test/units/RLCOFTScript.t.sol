// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Deploy as RLCOFTDeploy, Configure as RLCOFTConfigure} from "../../script/RLCOFT.s.sol";
import {RLCOFT} from "../../src/RLCOFT.sol";
import {RLCOFTTestSetup} from "./utils/RLCOFTTestSetup.sol";

contract RLCOFTScriptTest is RLCOFTTestSetup {
    RLCOFT public rlcOft;

    function setUp() public {
        rlcOft = RLCOFT(_forkArbitrumTestnetAndDeploy());
    }

    /**
     * Deployment
     */
    function test_CheckDeployment() public view {
        assertEq(rlcOft.owner(), vm.envAddress("OWNER_ADDRESS"));
        assertEq(rlcOft.token(), address(rlcOft));
    }
}
