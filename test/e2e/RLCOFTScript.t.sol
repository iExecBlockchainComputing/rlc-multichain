// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test,console} from "forge-std/Test.sol";
import {Deploy as RLCOFTDeploy, Configure as RLCOFTConfigure} from "../../script/RLCOFT.s.sol";
import {RLCOFT} from "../../src/RLCOFT.sol";

contract RLCOFTScriptTest is Test {
    mapping(bytes32 => bool) public ghostSalts;

    address constant CREATEX_FACTORY = 0xba5Ed099633D3B313e4D5F7bdc1305d3c28ba5Ed;

    // Instance unique du script de déploiement
    address owner = makeAddr("OWNER_ADDRESS");
    address pauser = makeAddr("PAUSER_ADDRESS");

    RLCOFTDeploy public deployer;

    function setUp() public {
        vm.createSelectFork("https://arbitrum-sepolia-rpc.publicnode.com"); // use public node

        vm.setEnv("RLC_OFT_TOKEN_NAME", "RLC OFT Token");
        vm.setEnv("RLC_TOKEN_SYMBOL", "RLC");
        vm.setEnv("LAYER_ZERO_ARBITRUM_SEPOLIA_ENDPOINT_ADDRESS", "0x6EDCE65403992e310A62460808c4b910D972f10f");
        vm.setEnv("OWNER_ADDRESS", vm.toString(owner));
        vm.setEnv("PAUSER_ADDRESS", vm.toString(pauser));
        vm.setEnv("CREATE_X_FACTORY_ADDRESS", vm.toString(CREATEX_FACTORY));
        
        deployer = new RLCOFTDeploy();
    }

    // // ============ Deployment Tests ============
    function test_CheckDeployment() public {
        RLCOFT rlcoft = RLCOFT(deployer.run());

        assertEq(rlcoft.owner(), vm.envAddress("OWNER_ADDRESS"));
        assertEq(rlcoft.token(), address(rlcoft));
    }

    function testFuzz_differentSaltsProduceDifferentAddresses(bytes32 salt1, bytes32 salt2) public {
        vm.assume(!ghostSalts[salt1]); // ensure salt1 is not already used
        vm.assume(!ghostSalts[salt2]); // ensure salt2 is not already used
        vm.assume(salt1 != salt2); // ensure they are different
        ghostSalts[salt1] = true;
        ghostSalts[salt2] = true;
        console.log("Salt1:", vm.toString(salt1));
        console.log("Salt2:", vm.toString(salt2));

        vm.setEnv("SALT", vm.toString(salt1));
        address addr1 = deployer.run();

        vm.setEnv("SALT", vm.toString(salt2));
        address addr2 = deployer.run();

        assertTrue(addr1 != addr2, "Fuzz test failed: different salts produced same address");
    }

    function testFuzz_redeploymentWithSameSaltFails(bytes32 salt) public {
        vm.assume(!ghostSalts[salt]); // ensure salt is not already used
        ghostSalts[salt] = true;
        console.log("Salt:", vm.toString(salt));

        // Premier déploiement
        vm.setEnv("SALT", vm.toString(salt));
        address addr = deployer.run();
        assertTrue(addr != address(0), "First deployment should succeed");

        try deployer.run() returns (address) {
            fail();  
        } catch {
            // Expected: revert due to CREATE2 address collision
        }
    }
}
