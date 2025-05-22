// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Deploy as RLCAdapterDeploy} from "../../script/RLCAdapter.s.sol";

contract RLCAdapterTestSetup is Test {

    function _forkSepoliaAndDeploy() internal returns (address) {
        vm.createSelectFork(vm.envString("SEPOLIA_RPC_URL"));
        return new RLCAdapterDeploy().run();
    }
}
