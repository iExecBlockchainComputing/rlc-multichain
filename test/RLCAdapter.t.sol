// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {Test, console} from "forge-std/Test.sol";
import {Deploy as RLCAdapterDeploy, Configure as RLCAdapterConfigure} from "../script/RLCAdapter.s.sol";
import {RLCAdapter} from "../src/RLCAdapter.sol";

contract RLCAdapterTest is Test, Initializable {
    RLCAdapter public rlcAdapter;

    function setUp() public {
        vm.createSelectFork(vm.envString("SEPOLIA_RPC_URL"));
        rlcAdapter = RLCAdapter(new RLCAdapterDeploy().run());
    }

    function test_RevertWhenInitializingTwoTimes() public {
        vm.expectRevert(InvalidInitialization.selector);
        rlcAdapter.initialize(address(0xabcd));
    }
}
