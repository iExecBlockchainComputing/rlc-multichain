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
import {ConfigLib} from "../../script/lib/ConfigLib.sol";

contract IexecLayerZeroBridgeScriptTest is Test {
    // The chain does not matter here as the LAYERZERO_ENDPOINT address is the same for both networks (Ethereum Mainnet & Arbitrum)
    ConfigLib.CommonConfigParams params = ConfigLib.readCommonConfig("sepolia");

    address admin = makeAddr("admin");
    address upgrader = makeAddr("upgrader");
    address pauser = makeAddr("pauser");
    bytes32 salt = keccak256("salt");

    IexecLayerZeroBridgeDeploy public deployer;
    address private liquidityUnifier;
    address private rlcCrosschainToken;

    // Forks ID
    uint256 private sepoliaFork;
    uint256 private arbitrumSepoliaFork;

    function setUp() public {
        deployer = new IexecLayerZeroBridgeDeploy();

        // Create a forks
        sepoliaFork = vm.createFork(vm.envString("SEPOLIA_RPC_URL"));
        arbitrumSepoliaFork = vm.createFork(vm.envString("ARBITRUM_SEPOLIA_RPC_URL"));

        // Setup Ethereum Mainnet fork
        vm.selectFork(sepoliaFork);
        liquidityUnifier = new RLCLiquidityUnifierDeployScript().deploy(
            params.rlcToken, admin, upgrader, params.createxFactory, keccak256("salt")
        );

        // Setup Arbitrum Sepolia fork
        vm.selectFork(arbitrumSepoliaFork);
        rlcCrosschainToken = new RLCCrosschainTokenDeployScript().deploy(
            "iEx.ec Network Token", "RLC", admin, admin, params.createxFactory, salt
        );
    }

    // ###############################################
    // Without ApprovalRequired
    // ###############################################

    function testFork_Deployment_WithoutApproval() public {
        vm.selectFork(arbitrumSepoliaFork);
        _test_Deployment(false, rlcCrosschainToken);
    }

    function testFork_RevertWhen_TwoDeploymentsWithTheSameSalt_WithoutApproval() public {
        vm.selectFork(arbitrumSepoliaFork);
        _test_TwoDeploymentsWithTheSameSalt(false, rlcCrosschainToken);
    }

    // ###############################################
    // With ApprovalRequired
    // ###############################################

    function testFork_Deployment_WithApproval() public {
        vm.selectFork(sepoliaFork);
        _test_Deployment(true, liquidityUnifier);
    }

    function testFork_RevertWhen_TwoDeploymentsWithTheSameSalt_WithApproval() public {
        vm.selectFork(sepoliaFork);
        _test_TwoDeploymentsWithTheSameSalt(true, liquidityUnifier);
    }

    // ###############################################
    // Common functions
    // ###############################################

    function _test_Deployment(bool requireApproval, address bridgeableToken) internal {
        IexecLayerZeroBridge iexecLayerZeroBridge = IexecLayerZeroBridge(
            deployer.deploy(
                requireApproval,
                bridgeableToken,
                params.lzEndpoint,
                admin,
                upgrader,
                pauser,
                params.createxFactory,
                salt
            )
        );

        assertEq(iexecLayerZeroBridge.owner(), admin);
        assertEq(iexecLayerZeroBridge.token(), requireApproval ? params.rlcToken : bridgeableToken);
        // Check ApprovalRequired value
        assertEq(iexecLayerZeroBridge.approvalRequired(), requireApproval, "Incorrect ApprovalRequired value");
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

    function _test_TwoDeploymentsWithTheSameSalt(bool requireApproval, address bridgeableToken) internal {
        deployer.deploy(
            requireApproval, bridgeableToken, params.lzEndpoint, admin, upgrader, pauser, params.createxFactory, salt
        );
        vm.expectRevert(abi.encodeWithSignature("FailedContractCreation(address)", params.createxFactory));
        deployer.deploy(
            requireApproval, bridgeableToken, params.lzEndpoint, admin, upgrader, pauser, params.createxFactory, salt
        );
    }

    // TODO add tests for the configuration script.

    function testFork_ConfigureContractCorrectly() public {
        // TODO check that the peer has been set with the correct config.
    }

    function testFork_RevertWhenPeerIsAlreadySet() public {}

    function testFork_RevertWhenAnyConfigurationVariableIsMissing() public {}
}
