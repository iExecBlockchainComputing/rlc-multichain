// SPDX-FileCopyrightText: 2025 IEXEC BLOCKCHAIN TECH <contact@iex.ec>
// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.22;

import {MessagingFee, SendParam, IOFT} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {IERC7802} from "@openzeppelin/contracts/interfaces/draft-IERC7802.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {TestHelperOz5} from "@layerzerolabs/test-devtools-evm-foundry/contracts/TestHelperOz5.sol";
import {IexecLayerZeroBridge} from "../../../../src/bridges/layerZero/IexecLayerZeroBridge.sol";
import {DualPausableUpgradeable} from "../../../../src/bridges/utils/DualPausableUpgradeable.sol";
import {TestUtils} from "../../utils/TestUtils.sol";
import {RLCCrosschainToken} from "../../../../src/RLCCrosschainToken.sol";
import {RLCLiquidityUnifier} from "../../../../src/RLCLiquidityUnifier.sol";
import {RLCMock} from "../../mocks/RLCMock.sol";

contract IexecLayerZeroBridgeHarnessTest is TestHelperOz5 {
    using TestUtils for *;

    // ============ STATE VARIABLES ============
    IexecLayerZeroBridge private iexecLayerZeroBridgeEthereum; // A chain with approval required.
    IexecLayerZeroBridge private iexecLayerZeroBridgeChainX;
    RLCCrosschainToken private rlcCrosschainToken;
    RLCLiquidityUnifier private rlcLiquidityUnifier;
    RLCMock private rlcToken;

    uint32 private constant SOURCE_EID = 1;
    uint32 private constant DEST_EID = 2;

    address private admin = makeAddr("admin");
    address private upgrader = makeAddr("upgrader");
    address private pauser = makeAddr("pauser");
    address private user1 = makeAddr("user1");
    address private user2 = makeAddr("user2");
    address private unauthorizedUser = makeAddr("unauthorizedUser");

    uint256 private constant INITIAL_BALANCE = 100 * 10 ** 9; // 100 RLC tokens with 9 decimals
    uint256 private constant TRANSFER_AMOUNT = 1 * 10 ** 9; // 1 RLC token with 9 decimals

    function setUp() public virtual override {
        super.setUp();
        setUpEndpoints(2, LibraryType.UltraLightNode);

        // Set up endpoints for the deployment
        address lzEndpointSource = address(endpoints[SOURCE_EID]); // Source endpoint for Sepolia - Destination endpoint for Arbitrum Sepolia
        address lzEndpointDestination = address(endpoints[DEST_EID]); // Source endpoint for Arbitrum Sepolia - Destination endpoint for Sepolia

        TestUtils.DeploymentResult memory deploymentResult2 = TestUtils.setupDeployment(
            TestUtils.DeploymentParams({
                iexecLayerZeroBridgeContractName: "IexecLayerZeroBridgeHarness",
                lzEndpointSource: lzEndpointSource,
                lzEndpointDestination: lzEndpointDestination,
                initialAdmin: admin,
                initialUpgrader: upgrader,
                initialPauser: pauser
            })
        );

        iexecLayerZeroBridgeEthereum = deploymentResult2.iexecLayerZeroBridgeChainA;
        iexecLayerZeroBridgeChainX = deploymentResult2.iexecLayerZeroBridgeChainB;
        rlcToken = deploymentResult2.rlcToken;
        rlcCrosschainToken = deploymentResult2.rlcCrosschainToken;
        rlcLiquidityUnifier = deploymentResult2.rlcLiquidityUnifier;

        address iexecLayerZeroBridgeEthereumAddress = address(iexecLayerZeroBridgeEthereum);
        address iexecLayerZeroBridgeChainXAddress = address(iexecLayerZeroBridgeChainX);
        // Wire the contracts
        address[] memory contracts = new address[](2);
        contracts[0] = iexecLayerZeroBridgeEthereumAddress; // Index 0 → EID 1
        contracts[1] = iexecLayerZeroBridgeChainXAddress; // Index 1 → EID 2
        vm.startPrank(admin);
        wireOApps(contracts);
        vm.stopPrank();

        // ### Setup for chainX ###
        // Authorize the bridge to mint/burn tokens.
        vm.startPrank(admin);
        rlcCrosschainToken.grantRole(rlcCrosschainToken.TOKEN_BRIDGE_ROLE(), iexecLayerZeroBridgeChainXAddress);
        vm.stopPrank();

        // Mint RLC tokens to user1
        vm.prank(iexecLayerZeroBridgeChainXAddress);
        rlcCrosschainToken.crosschainMint(user1, INITIAL_BALANCE);

        // ### Setup for Ethereum Mainnet ###
        // Authorize the bridge to lock/unLock tokens.
        vm.startPrank(admin);
        rlcLiquidityUnifier.grantRole(rlcLiquidityUnifier.TOKEN_BRIDGE_ROLE(), iexecLayerZeroBridgeEthereumAddress);
        vm.stopPrank();

        // Transfer initial RLC balance to user1
        rlcToken.transfer(user1, INITIAL_BALANCE);

        //Add label to make logs more readable
        vm.label(iexecLayerZeroBridgeEthereumAddress, "iexecLayerZeroBridgeEthereum");
        vm.label(iexecLayerZeroBridgeChainXAddress, "iexecLayerZeroBridgeChainX");
        vm.label(address(rlcToken), "rlcToken");
        vm.label(address(rlcCrosschainToken), "rlcCrosschainToken");
        vm.label(address(rlcLiquidityUnifier), "rlcLiquidityUnifier");
    }

    // ============ _credit ============
    function test_credit_SuccessfulMintToUser() public {
        // Test successful minting to a regular user address
        uint256 mintAmount = TRANSFER_AMOUNT;
        uint256 initialBalance = rlcCrosschainToken.balanceOf(user2);

        vm.expectEmit(true, true, true, true);
        emit Transfer(address(0), user2, mintAmount);

        uint256 amountReceived = iexecLayerZeroBridgeChainX.exposed_credit(user2, mintAmount, SOURCE_EID);

        assertEq(amountReceived, mintAmount, "Amount received should equal mint amount");
        assertEq(
            rlcCrosschainToken.balanceOf(user2),
            initialBalance + mintAmount,
            "User balance should increase by mint amount"
        );
    }

    function test_credit_ZeroAddressRedirection() public {
        // Test that minting to zero address redirects to 0xdead address
        uint256 mintAmount = TRANSFER_AMOUNT;
        address deadAddress = address(0xdead);
        uint256 initialBalance = rlcCrosschainToken.balanceOf(deadAddress);

        vm.expectEmit(true, true, true, true);
        emit IERC20.Transfer(address(0), deadAddress, mintAmount);

        uint256 amountReceived = iexecLayerZeroBridgeChainX.exposed_credit(address(0), mintAmount, SOURCE_EID);

        assertEq(amountReceived, mintAmount, "Amount received should equal mint amount");
        assertEq(
            rlcCrosschainToken.balanceOf(deadAddress),
            initialBalance + mintAmount,
            "Dead address balance should increase by mint amount"
        );
        assertEq(rlcCrosschainToken.balanceOf(address(0)), 0, "Zero address balance should remain zero");
    }

    function testFuzz_credit_Address(address to) public {
        // Fuzz test with different addresses
        vm.assume(to != address(0)); // Exclude zero address as it gets redirected

        uint256 mintAmount = TRANSFER_AMOUNT;
        uint256 initialBalance = rlcCrosschainToken.balanceOf(to);

        uint256 amountReceived = iexecLayerZeroBridgeChainX.exposed_credit(to, mintAmount, SOURCE_EID);

        assertEq(amountReceived, mintAmount, "Amount received should equal mint amount");
        assertEq(rlcCrosschainToken.balanceOf(to), initialBalance + mintAmount, "Address balance should increase");
    }

    function testFuzz_credit_Amount(uint256 amount) public {
        // Fuzz test with different amounts
        vm.assume(amount > 0 && amount < type(uint128).max); // Reasonable bounds to avoid overflow

        uint256 initialBalance = rlcCrosschainToken.balanceOf(user2);

        uint256 amountReceived = iexecLayerZeroBridgeChainX.exposed_credit(user2, amount, SOURCE_EID);

        assertEq(amountReceived, amount, "Amount received should equal mint amount");
        assertEq(
            rlcCrosschainToken.balanceOf(user2), initialBalance + amount, "User balance should increase by mint amount"
        );
    }

    function test_credit_RevertsWhenFullyPaused() public {
        // Test that _credit reverts when contract is fully paused
        uint256 mintAmount = TRANSFER_AMOUNT;

        // Pause the contract
        vm.prank(pauser);
        iexecLayerZeroBridgeChainX.pause();

        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        iexecLayerZeroBridgeChainX.exposed_credit(user2, mintAmount, SOURCE_EID);
    }

    function test_credit_WorksWhenOnlySendPaused() public {
        // Test that _credit still works when only sends are paused (Level 2 pause)
        uint256 mintAmount = TRANSFER_AMOUNT;
        uint256 initialBalance = rlcCrosschainToken.balanceOf(user2);

        // Pause only sends
        vm.prank(pauser);
        iexecLayerZeroBridgeChainX.pauseSend();

        vm.expectEmit(true, true, true, true);
        emit IERC20.Transfer(address(0), user2, mintAmount);

        uint256 amountReceived = iexecLayerZeroBridgeChainX.exposed_credit(user2, mintAmount, SOURCE_EID);

        assertEq(amountReceived, mintAmount, "Amount received should equal mint amount");
        assertEq(rlcCrosschainToken.balanceOf(user2), initialBalance + mintAmount, "User balance should increase");
    }

    function test_credit_WorksAfterUnpause() public {
        // Test that _credit works after unpausing
        uint256 mintAmount = TRANSFER_AMOUNT;
        uint256 initialBalance = rlcCrosschainToken.balanceOf(user2);

        // Pause the contract
        vm.prank(pauser);
        iexecLayerZeroBridgeChainX.pause();

        // Verify it's paused
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        iexecLayerZeroBridgeChainX.exposed_credit(user2, mintAmount, SOURCE_EID);

        // Unpause the contract
        vm.prank(pauser);
        iexecLayerZeroBridgeChainX.unpause();

        // Now it should work
        vm.expectEmit(true, true, true, true);
        emit IERC20.Transfer(address(0), user2, mintAmount);

        uint256 amountReceived = iexecLayerZeroBridgeChainX.exposed_credit(user2, mintAmount, SOURCE_EID);

        assertEq(amountReceived, mintAmount, "Amount received should equal mint amount");
        assertEq(rlcCrosschainToken.balanceOf(user2), initialBalance + mintAmount, "User balance should increase");
    }
}
