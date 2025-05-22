// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {Test, console} from "forge-std/Test.sol";
import {RLCAdapterTestSetup } from "./utils/RLCAdapterTestSetup.sol";
import {RLCAdapter} from "../src/RLCAdapter.sol";

contract RLCAdapterTest is RLCAdapterTestSetup, Initializable {
    RLCAdapter public rlcAdapter;

    function setUp() public {
        rlcAdapter = RLCAdapter(_forkSepoliaAndDeploy());
    }

    function test_RevertWhenInitializingTwoTimes() public {
        vm.expectRevert(InvalidInitialization.selector);
        rlcAdapter.initialize(address(0xabcd));
    }
}
