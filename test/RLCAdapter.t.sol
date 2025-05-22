// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Deploy as RLCAdapterDeploy, Configure as RLCAdapterConfigure} from "../script/RLCAdapter.s.sol";
import {RLCAdapter} from "../src/RLCAdapter.sol";

contract RLCAdapterTest is Test {
    RLCAdapter public rlcAdapter;

    function setUp() public {
        rlcAdapter = RLCAdapter(new RLCAdapterDeploy().run());
    }

    function test_Increment() public {
        // counter.increment();
        // assertEq(counter.number(), 1);
    }

    function testFuzz_SetNumber(uint256 x) public {
        // counter.setNumber(x);
        // assertEq(counter.number(), x);
    }
}
