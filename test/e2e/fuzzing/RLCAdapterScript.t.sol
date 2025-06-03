// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {Test, console} from "forge-std/Test.sol";
import {Deploy as RLCAdapterDeploy} from "../../../script/RLCAdapter.s.sol";
import {RLCAdapter} from "../../../src/RLCAdapter.sol";
import {ITokenSpender} from "../../../src/ITokenSpender.sol";

contract RLCAdapterScriptTest is Test {
    RLCAdapter public rlcAdapter;

    address public owner;
    address public bridge;
    address public pauser;
    address public user1;
    address public user2;

    // Events to test
    event Paused(address account);
    event Unpaused(address account);
    event Transfer(address indexed from, address indexed to, uint256 value);

    // Custom errors from OpenZeppelin
    error EnforcedPause();
    error AccessControlUnauthorizedAccount(address account, bytes32 neededRole);

    function setUp() public {
        vm.createSelectFork(vm.envString("ARBITRUM_SEPOLIA_RPC_URL"));

        // Create addresses using makeAddr
        owner = makeAddr("owner");
        bridge = makeAddr("bridge");
        pauser = makeAddr("pauser");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        // Set up environment variables for the deployment
        vm.setEnv("RLC_OFT_TOKEN_NAME", "RLC OFT Test");
        vm.setEnv("RLC_TOKEN_SYMBOL", "RLCT");
        vm.setEnv("LAYER_ZERO_ARBITRUM_SEPOLIA_ENDPOINT_ADDRESS", "0x6EDCE65403992e310A62460808c4b910D972f10f");
        vm.setEnv("OWNER_ADDRESS", vm.toString(owner));
        vm.setEnv("PAUSER_ADDRESS", vm.toString(pauser));

        // // Deploy the contract using the deployment script
        // rlcAdapter = RLCAdapter(new RLCAdapterDeploy().run());
    }

    // ============ Deployment Tests ============
    function testDeployment() public {}
}
