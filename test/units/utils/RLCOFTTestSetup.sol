// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Deploy as RLCOFTDeploy} from "../../../script/RLCOFT.s.sol";

contract RLCOFTTestSetup is Test {
    function _forkArbitrumTestnetAndDeploy() internal returns (address) {
        vm.createSelectFork("https://arbitrum-sepolia-rpc.publicnode.com"); // use public ndde
        return new RLCOFTDeploy().run();
    }
}
