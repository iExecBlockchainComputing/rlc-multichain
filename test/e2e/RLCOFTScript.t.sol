// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Deploy as RLCOFTDeploy, Configure as RLCOFTConfigure} from "../../script/RLCOFT.s.sol";
import {RLCOFT} from "../../src/RLCOFT.sol";

contract RLCOFTScriptTest is Test {
    // Instance unique du script de déploiement
    string name = "RLC OFT Token";
    string symbol = "RLC";
    address lzEndpoint = 0x6EDCE65403992e310A62460808c4b910D972f10f; // LayerZero Arbitrum Sepolia endpoint
    address owner = makeAddr("OWNER_ADDRESS");
    address pauser = makeAddr("PAUSER_ADDRESS");
    address constant createXFactory = 0xba5Ed099633D3B313e4D5F7bdc1305d3c28ba5Ed;

    RLCOFTDeploy public deployer;

    function setUp() public {
        vm.createSelectFork("https://arbitrum-sepolia-rpc.publicnode.com"); // use public node
        deployer = new RLCOFTDeploy();
    }

    // ============ Deployment Tests ============
    function test_CheckDeployment() public {
        bytes32 salt = keccak256("RLCOFT_SALT");
        RLCOFT rlcoft = RLCOFT(deployer.deploy(lzEndpoint, name, symbol, owner, pauser, createXFactory, salt));

        assertEq(rlcoft.owner(), owner);
        assertEq(rlcoft.token(), address(rlcoft));
    }

    function testFuzz_differentSaltsProduceDifferentAddresses(bytes32 salt1, bytes32 salt2) public {
        vm.assume(salt1 != salt2); // ensure they are different

        address addr1 = deployer.deploy(lzEndpoint, name, symbol, owner, pauser, createXFactory, salt1);
        address addr2 = deployer.deploy(lzEndpoint, name, symbol, owner, pauser, createXFactory, salt2);

        assertTrue(addr1 != addr2, "Fuzz test failed: different salts produced same address");
    }

    function testFuzz_redeploymentWithSameSaltFails(bytes32 salt) public {
        // Premier déploiement
        address addr = deployer.deploy(lzEndpoint, name, symbol, owner, pauser, createXFactory, salt);
        assertTrue(addr != address(0), "First deployment should succeed");

        try deployer.deploy(lzEndpoint, name, symbol, owner, pauser, createXFactory, salt) returns (address) {
            revert("Expected revert on redeployment with same salt but no revert occurred");
        } catch {
            // Expected: revert due to CREATE2 address collision
        }
    }
}
