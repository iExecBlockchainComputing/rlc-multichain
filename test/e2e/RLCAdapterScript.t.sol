// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {Deploy as RLCAdapterDeploy} from "../../script/bridges/layerZero/RLCAdapter.s.sol";
import {RLCAdapter} from "../../src/bridges/layerZero/RLCAdapter.sol";

contract RLCAdapterScriptTest is Test {
    // Unique instance of the deployment script
    address lzEndpoint = 0x6EDCE65403992e310A62460808c4b910D972f10f; // LayerZero Arbitrum Sepolia endpoint
    address owner = makeAddr("OWNER_ADDRESS");
    address pauser = makeAddr("PAUSER_ADDRESS");
    address RLC_TOKEN = 0x26A738b6D33EF4D94FF084D3552961b8f00639Cd;
    address createx = 0xba5Ed099633D3B313e4D5F7bdc1305d3c28ba5Ed;

    RLCAdapterDeploy public deployer;

    function setUp() public {
        // TODO use vm.rpcUrl("sepolia")
        vm.createSelectFork(vm.envString("SEPOLIA_RPC_URL"));
        deployer = new RLCAdapterDeploy();
        vm.setEnv("CREATE_X_FACTORY", vm.toString(createx));
    }

    // ============ Deployment Tests ============
    function testFork_CheckDeployment() public {
        bytes32 salt = keccak256("RLCAdapter_SALT");
        RLCAdapter rlcAdapter = RLCAdapter(deployer.deploy(lzEndpoint, owner, pauser, salt, RLC_TOKEN));

        assertEq(rlcAdapter.owner(), owner);
        assertEq(rlcAdapter.token(), RLC_TOKEN);
        // Check all roles.
        assertTrue(rlcAdapter.hasRole(rlcAdapter.DEFAULT_ADMIN_ROLE(), owner), "Owner should have DEFAULT_ADMIN_ROLE");
        // TODO assertTrue(rlcAdapter.hasRole(rlcAdapter.UPGRADER_ROLE(), owner), "Owner should have UPGRADER_ROLE");
        assertTrue(rlcAdapter.hasRole(rlcAdapter.PAUSER_ROLE(), pauser), "Pauser should have PAUSER_ROLE");
        // Make sure the contract is not paused by default.
        assertFalse(rlcAdapter.paused(), "Contract should not be paused by default");
        // Make sure the contract has been initialized and cannot be re-initialized.
        vm.expectRevert(abi.encodeWithSelector(Initializable.InvalidInitialization.selector));
        rlcAdapter.initialize(owner, pauser);
        // TODO check that the contract has the correct LayerZero endpoint.
        // TODO check that the proxy address is saved.
    }

    // Makes sure create2 deployment is well implemented.
    function test_RevertWhen_TwoDeploymentsWithTheSameSalt() public {
        bytes32 salt = keccak256("salt");
        deployer.deploy(lzEndpoint, owner, pauser, salt, RLC_TOKEN);
        vm.expectRevert(abi.encodeWithSignature("FailedContractCreation(address)", createx));
        deployer.deploy(lzEndpoint, owner, pauser, salt, RLC_TOKEN);
    }

    // TODO add tests for the configuration script.

    function testFork_ConfigureContractCorrectly() public {
        // TODO check that the peer has been set with the correct config.
    }

    function testFork_RevertWhenPeerIsAlreadySet() public {}

    function testFork_RevertWhenAnyConfigurationVariableIsMissing() public {}
}
