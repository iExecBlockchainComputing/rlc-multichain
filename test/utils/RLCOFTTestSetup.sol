// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Deploy as RLCOFTDeploy} from "../../script/RLCOFT.s.sol";

contract RLCOFTTestSetup is Test {

    function _forkArbitrumTestnetAndDeploy() internal returns (address) {
        vm.createSelectFork(vm.envString("ARBITRUM_SEPOLIA_RPC_URL"));
        return new RLCOFTDeploy().run();
    }
}
