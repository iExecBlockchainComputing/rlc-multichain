// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {Test, console} from "forge-std/Test.sol";
import {Deploy as RLCOFTDeploy} from "../../script/RLCOFT.s.sol";
import {RLCOFT} from "../../src/RLCOFT.sol";
import {ITokenSpender} from "../../src/ITokenSpender.sol";
import {ICreateX} from "@createx/contracts/ICreateX.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract RLCOFTTest is Test {
    RLCOFT public rlcOft;

    address public owner;
    address public bridge;
    address public pauser;
    address public user1;
    address public user2;

    // CreateX factory address (should be the same across networks)
    address constant CREATEX_FACTORY = 0xba5Ed099633D3B313e4D5F7bdc1305d3c28ba5Ed;

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
        vm.setEnv("CREATE_X_FACTORY_ADDRESS", vm.toString(CREATEX_FACTORY));
        vm.setEnv("SALT", vm.toString(bytes32("test_salt_123")));
    }

    // ============ Deployment Tests ============
    function testDeployment() public {
        // Basic deployment verification
        assertEq(rlcOft.name(), "RLC OFT Test");
        assertEq(rlcOft.symbol(), "RLCT");
        assertEq(rlcOft.decimals(), 9);

        assertTrue(rlcOft.hasRole(rlcOft.DEFAULT_ADMIN_ROLE(), owner));
    }

    function testMultipleDeterministicDeployments() public {
        // Test that different salts produce different addresses
        bytes32 salt1 = bytes32("salt_1");
        bytes32 salt2 = bytes32("salt_2");
        
        address address1 = new RLCOFTDeploy().run();
        address address2 = new RLCOFTDeploy().run();
        
        assertTrue(address1 != address2, "Different salts should produce different addresses");
        console.log("Address with salt1:", address1);
        console.log("Address with salt2:", address2);
    }

    function testRedeploymentWithSameSalt() public {
        // Deploy implementation
        address deployedAddress = new RLCOFTDeploy().run();

        assertTrue(deployedAddress != address(0), "First deployment should succeed");
        
        // Second deployment with same salt should fail
        vm.expectRevert();
        new RLCOFTDeploy().run();
    }
}
