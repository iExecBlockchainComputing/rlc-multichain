// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Deploy as RLCOFTDeploy, Configure as RLCOFTConfigure} from "../script/RLCOFT.s.sol";
import {RLCOFT} from "../src/RLCOFT.sol";

contract RLCOFTTest is Test {
    RLCOFT public rlcOft;

    function setUp() public {
        rlcOft = RLCOFT(new RLCOFTDeploy().run());
    }
}
