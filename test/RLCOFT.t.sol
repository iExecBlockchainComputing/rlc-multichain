// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {Test, console} from "forge-std/Test.sol";
import {RLCOFT} from "../src/RLCOFT.sol";
import {RLCOFTTestSetup} from "./utils/RLCOFTTestSetup.sol";

contract RLCOFTTest is RLCOFTTestSetup, Initializable {
    RLCOFT public rlcOft;

    function setUp() public {
        rlcOft = RLCOFT(_forkArbitrumTestnetAndDeploy());
    }

    function test_RevertWhenInitializingTwoTimes() public {
        vm.expectRevert(InvalidInitialization.selector);
        rlcOft.initialize("Foo", "BAR", address(0xabcd));
    }
}
