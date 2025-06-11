// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {Deploy as RLCAdapterDeploy} from "../../script/RLCAdapter.s.sol";
import {RLCAdapter} from "../../src/RLCAdapter.sol";

contract RLCAdapterScriptTest is Test {
    // Unique instance of the deployment script
    address lzEndpoint = 0x6EDCE65403992e310A62460808c4b910D972f10f; // LayerZero Arbitrum Sepolia endpoint
    address owner = makeAddr("OWNER_ADDRESS");
    address pauser = makeAddr("PAUSER_ADDRESS");
    address RLC_TOKEN = 0x26A738b6D33EF4D94FF084D3552961b8f00639Cd;

    RLCAdapterDeploy public deployer;

    function setUp() public {
        // TODO use vm.rpcUrl("sepolia")
        vm.createSelectFork(vm.envString("SEPOLIA_RPC_URL"));
        deployer = new RLCAdapterDeploy();
        vm.setEnv("CREATE_X_FACTORY", "0xba5Ed099633D3B313e4D5F7bdc1305d3c28ba5Ed");
    }

    // ============ Deployment Tests ============
    function testFork_CheckDeployment() public {
        bytes32 salt = keccak256("RLCOFT_SALT");
        RLCAdapter rlcAdapter = RLCAdapter(deployer.deploy(lzEndpoint, owner, pauser, salt, RLC_TOKEN));

        assertEq(rlcAdapter.owner(), owner);
        assertEq(rlcAdapter.token(), RLC_TOKEN);
        // TODO check all roles.
        // TODO check that the contract is not paused by default.
        // TODO check that the contract has been initialized and cannot be re-initialized.
        // TODO check that the contract has the correct LayerZero endpoint.
        // TODO check that the proxy address is saved.
    }

    function testForkFuzz_DifferentSaltsProduceDifferentAddresses(bytes32 salt1, bytes32 salt2) public {
        vm.assume(salt1 != salt2); // ensure they are different

        address addr1 = deployer.deploy(lzEndpoint, owner, pauser, salt1, RLC_TOKEN);
        address addr2 = deployer.deploy(lzEndpoint, owner, pauser, salt2, RLC_TOKEN);

        assertTrue(addr1 != addr2, "Fuzz test failed: different salts produced same address");
    }

    function testForkFuzz_RevertIfSecondDeploymentWithSameSalt(bytes32 salt) public {
        // First deployment
        address addr = deployer.deploy(lzEndpoint, owner, pauser, salt, RLC_TOKEN);
        assertTrue(addr != address(0), "First deployment should succeed");

        // Attempt redeployment with the same salt
        try deployer.deploy(lzEndpoint, owner, pauser, salt, RLC_TOKEN) returns (address) {
            revert("Expected revert on redeployment with same salt but no revert occurred");
        } catch {
            // Expected: revert due to CREATE2 address collision
        }
    }

    // TODO add tests for the configuration script.

    function testFork_ConfigureContractCorrectly() public {
        // TODO check that the peer has been set with the correct config.
    }

    function testFork_RevertWhenPeerIsAlreadySet() public {}

    function testFork_RevertWhenAnyConfigurationVariableIsMissing() public {}
}
