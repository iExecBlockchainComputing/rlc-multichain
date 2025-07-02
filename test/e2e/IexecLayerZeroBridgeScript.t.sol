// SPDX-FileCopyrightText: 2025 IEXEC BLOCKCHAIN TECH <contact@iex.ec>
// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.22;

import {Test} from "forge-std/Test.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {Deploy as IexecLayerZeroBridgeDeploy} from "../../script/bridges/layerZero/IexecLayerZeroBridge.s.sol";
import {Deploy as RLCLiquidityUnifierDeployScript} from "../../script/RLCLiquidityUnifier.s.sol";
import {Deploy as RLCCrosschainTokenDeployScript} from "../../script/RLCCrosschainToken.s.sol";
import {IexecLayerZeroBridge} from "../../src/bridges/layerZero/IexecLayerZeroBridge.sol";
import {RLCLiquidityUnifier} from "../../src/RLCLiquidityUnifier.sol";
import {RLCCrosschainToken} from "../../src/RLCCrosschainToken.sol";

/**
 * Test Script for the IexecLayerZeroBridge on Ethereum Mainnet.
 * In this case, IexecLayerZeroBridge should be connected to
 * RLCLiquidityUnifier contract deployed on the same chain.
 */
contract IexecLayerZeroBridgeScriptTest is Test {
    // TODO read value from config.json file.
    address LAYERZERO_ENDPOINT = 0x6EDCE65403992e310A62460808c4b910D972f10f; // LayerZero Arbitrum Sepolia endpoint
    address CREATEX = 0xba5Ed099633D3B313e4D5F7bdc1305d3c28ba5Ed;
    address rlcAddress = 0x26A738b6D33EF4D94FF084D3552961b8f00639Cd;

    address admin = makeAddr("admin");
    address upgrader = makeAddr("upgrader");
    address pauser = makeAddr("pauser");
    bytes32 salt = keccak256("salt");

    IexecLayerZeroBridgeDeploy public deployer;
    address private liquidityUnifier;
    address private rlcCrosschain;

    // Forks ID
    uint256 private ethereumMainnetFork;
    uint256 private arbitrumFork;

    function setUp() public {
        deployer = new IexecLayerZeroBridgeDeploy();

        // Create a forks
        ethereumMainnetFork = vm.createFork(vm.envString("SEPOLIA_RPC_URL"));
        arbitrumFork = vm.createFork(vm.envString("ARBITRUM_SEPOLIA_RPC_URL"));

        // Setup Ethereum Mainnet fork
        vm.selectFork(ethereumMainnetFork);
        liquidityUnifier = new RLCLiquidityUnifierDeployScript().deploy(
            address(rlcAddress), admin, upgrader, CREATEX, keccak256("salt")
        );

        // Setup Arbitrum Sepolia fork
        vm.selectFork(arbitrumFork);
        rlcCrosschain =
            new RLCCrosschainTokenDeployScript().deploy("iEx.ec Network Token", "RLC", admin, admin, CREATEX, salt);
    }

    // ###############################################
    // Without ApprovalRequired
    // ###############################################

    function testFork_DeploymentOnChainWithoutApproval() public {
        vm.selectFork(arbitrumFork);
        _testDeployment(false, rlcCrosschain);
    }

    function testFork_RevertWhen_TwoDeploymentsWithTheSameSaltWithoutApproval() public {
        vm.selectFork(arbitrumFork);
        _testTwoDeploymentsWithTheSameSalt(false, rlcCrosschain);
    }

    // ###############################################
    // With ApprovalRequired
    // ###############################################

    function testFork_DeploymentOnChainWithApproval() public {
        vm.selectFork(ethereumMainnetFork);
        _testDeployment(true, liquidityUnifier);
    }

    function testFork_RevertWhen_TwoDeploymentsWithTheSameSaltWithApproval() public {
        vm.selectFork(ethereumMainnetFork);
        _testTwoDeploymentsWithTheSameSalt(true, liquidityUnifier);
    }

    // ###############################################
    // Common functions
    // ###############################################

    function _testDeployment(bool _requireApproval, address bridgeableToken) internal {
        IexecLayerZeroBridge iexecLayerZeroBridge = IexecLayerZeroBridge(
            deployer.deploy(
                _requireApproval, bridgeableToken, LAYERZERO_ENDPOINT, admin, upgrader, pauser, CREATEX, salt
            )
        );

        assertEq(iexecLayerZeroBridge.owner(), admin);
        assertEq(iexecLayerZeroBridge.token(), _requireApproval ? rlcAddress : bridgeableToken);
        // Check ApprovalRequired value
        assertEq(iexecLayerZeroBridge.approvalRequired(), _requireApproval, "Incorrect ApprovalRequired value");
        // Check all roles.
        assertTrue(iexecLayerZeroBridge.hasRole(iexecLayerZeroBridge.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(iexecLayerZeroBridge.hasRole(iexecLayerZeroBridge.UPGRADER_ROLE(), upgrader));
        assertTrue(iexecLayerZeroBridge.hasRole(iexecLayerZeroBridge.PAUSER_ROLE(), pauser));
        // Make sure the contract is not paused by default.
        assertFalse(iexecLayerZeroBridge.paused(), "Contract should not be paused by default");
        // Make sure the contract has been initialized and cannot be re-initialized.
        vm.expectRevert(abi.encodeWithSelector(Initializable.InvalidInitialization.selector));
        iexecLayerZeroBridge.initialize(admin, upgrader, pauser);
        // TODO check that the contract has the correct LayerZero endpoint.
        // TODO check that the proxy address is saved.
    }

    function _testTwoDeploymentsWithTheSameSalt(bool _requireApproval, address bridgeableToken) internal {
        deployer.deploy(_requireApproval, bridgeableToken, LAYERZERO_ENDPOINT, admin, upgrader, pauser, CREATEX, salt);
        vm.expectRevert(abi.encodeWithSignature("FailedContractCreation(address)", CREATEX));
        deployer.deploy(_requireApproval, bridgeableToken, LAYERZERO_ENDPOINT, admin, upgrader, pauser, CREATEX, salt);
    }

    // TODO add tests for the configuration script.

    function testFork_ConfigureContractCorrectly() public {
        // TODO check that the peer has been set with the correct config.
    }

    function testFork_RevertWhenPeerIsAlreadySet() public {}

    function testFork_RevertWhenAnyConfigurationVariableIsMissing() public {}
}
