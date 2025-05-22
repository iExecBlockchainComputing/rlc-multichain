// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {Test, console} from "forge-std/Test.sol";
import {Deploy as RLCOFTDeploy, Configure as RLCOFTConfigure} from "../script/RLCOFT.s.sol";
import {RLCOFT} from "../src/RLCOFT.sol";

contract RLCOFTTest is Test, Initializable {
    RLCOFT public rlcOft;

    function setUp() public {
        vm.createSelectFork(vm.envString("ARBITRUM_SEPOLIA_RPC_URL"));
        rlcOft = RLCOFT(new RLCOFTDeploy().run());
    }

    function test_RevertWhenInitializingTwoTimes() public {
        vm.expectRevert(InvalidInitialization.selector);
        rlcOft.initialize("Foo", "BAR", address(0xabcd));
    }
}
