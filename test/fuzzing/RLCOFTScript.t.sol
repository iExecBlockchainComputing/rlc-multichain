// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {Test, console} from "forge-std/Test.sol";
import {Deploy as RLCOFTDeploy} from "../../script/RLCOFT.s.sol";
import {RLCOFT} from "../../src/RLCOFT.sol";

contract RLCOFTInvariant is Test {
    mapping(bytes32 => address) public deployed;

    // CreateX factory address (should be the same across networks)
    address constant CREATEX_FACTORY = 0xba5Ed099633D3B313e4D5F7bdc1305d3c28ba5Ed;

    function setUp() public {
        vm.createSelectFork(vm.envString("ARBITRUM_SEPOLIA_RPC_URL"));

        address owner = makeAddr("owner");
        address pauser = makeAddr("pauser");

        // Set up environment variables for the deployment
        vm.setEnv("RLC_OFT_TOKEN_NAME", "RLC OFT Test");
        vm.setEnv("RLC_TOKEN_SYMBOL", "RLCT");
        vm.setEnv("LAYER_ZERO_ARBITRUM_SEPOLIA_ENDPOINT_ADDRESS", "0x6EDCE65403992e310A62460808c4b910D972f10f");
        vm.setEnv("OWNER_ADDRESS", vm.toString(owner));
        vm.setEnv("PAUSER_ADDRESS", vm.toString(pauser));
        vm.setEnv("CREATE_X_FACTORY_ADDRESS", vm.toString(CREATEX_FACTORY));
    }

    // ============ Deployment Tests ============
    function testFuzz_differentSaltsProduceDifferentAddresses(bytes32 salt1, bytes32 salt2) public {
        vm.assume(salt1 != salt2); // ensure they are different

        vm.setEnv("SALT", vm.toString(salt1));
        address addr1 = new RLCOFTDeploy().run();
        vm.setEnv("SALT", vm.toString(salt2));
        address addr2 = new RLCOFTDeploy().run();

        assertTrue(addr1 != addr2, "Fuzz test failed: different salts produced same address");
    }

    function testFuzz_redeploymentWithSameSaltFails(bytes32 salt) public {
        vm.setEnv("SALT", vm.toString(salt));
        address addr = new RLCOFTDeploy().run();
        assertTrue(addr != address(0), "First deployment should succeed");

        // Second deployment with same salt should revert
        try new RLCOFTDeploy().run() returns (address) {
            fail();
        } catch {
            // Expected: revert due to CREATE2 address collision
        }
    }
}
