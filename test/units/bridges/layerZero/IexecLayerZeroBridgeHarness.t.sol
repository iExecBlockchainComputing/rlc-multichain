// SPDX-FileCopyrightText: 2025 IEXEC BLOCKCHAIN TECH <contact@iex.ec>
// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.22;

import {MessagingFee, SendParam, IOFT} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {IERC7802} from "@openzeppelin/contracts/interfaces/draft-IERC7802.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {TestHelperOz5} from "@layerzerolabs/test-devtools-evm-foundry/contracts/TestHelperOz5.sol";
import {IexecLayerZeroBridgeHarness} from "../../../../src/mocks/IexecLayerZeroBridgeHarness.sol";
import {DualPausableUpgradeable} from "../../../../src/bridges/utils/DualPausableUpgradeable.sol";
import {TestUtils} from "../../utils/TestUtils.sol";
import {RLCCrosschainToken} from "../../../../src/RLCCrosschainToken.sol";
import {RLCLiquidityUnifier} from "../../../../src/RLCLiquidityUnifier.sol";
import {RLCMock} from "../../mocks/RLCMock.sol";

contract IexecLayerZeroBridgeHarnessTest is TestHelperOz5 {
    using TestUtils for *;

    // ============ STATE VARIABLES ============
    IexecLayerZeroBridgeHarness private iexecLayerZeroBridgeEthereum; // A chain with approval required.
    IexecLayerZeroBridgeHarness private iexecLayerZeroBridgeChainX;
    RLCCrosschainToken private rlcCrosschainToken;

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

        TestUtils.DeploymentResult memory deploymentResult = TestUtils.setupDeployment(
            TestUtils.DeploymentParams({
                iexecLayerZeroBridgeContractName: "IexecLayerZeroBridgeHarness",
                lzEndpointSource: lzEndpointSource,
                lzEndpointDestination: lzEndpointDestination,
                initialAdmin: admin,
                initialUpgrader: upgrader,
                initialPauser: pauser
            })
        );

        address iexecLayerZeroBridgeEthereumAddress = address(deploymentResult.iexecLayerZeroBridgeChainWithApproval);
        address iexecLayerZeroBridgeChainXAddress = address(deploymentResult.iexecLayerZeroBridgeChainWithoutApproval);
        iexecLayerZeroBridgeChainX = IexecLayerZeroBridgeHarness(iexecLayerZeroBridgeEthereumAddress);
        iexecLayerZeroBridgeChainX = IexecLayerZeroBridgeHarness(iexecLayerZeroBridgeChainXAddress);
        rlcCrosschainToken = deploymentResult.rlcCrosschainToken;

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

        //Add label to make logs more readable
        vm.label(iexecLayerZeroBridgeChainXAddress, "iexecLayerZeroBridgeChainX");
        vm.label(address(rlcCrosschainToken), "rlcCrosschainToken");
    }

    // ============ _credit ============
    function test_credit_SuccessfulMintToUser() public {
        // Test successful minting to a regular user address
        uint256 initialBalance = rlcCrosschainToken.balanceOf(user2);

        vm.expectEmit(true, true, true, true);
        emit IERC20.Transfer(address(0), user2, TRANSFER_AMOUNT);

        uint256 amountReceived = iexecLayerZeroBridgeChainX.exposed_credit(user2, TRANSFER_AMOUNT, SOURCE_EID);

        assertEq(amountReceived, TRANSFER_AMOUNT, "Amount received should equal mint amount");
        assertEq(
            rlcCrosschainToken.balanceOf(user2),
            initialBalance + TRANSFER_AMOUNT,
            "User balance should increase by mint amount"
        );
    }

    function testFuzz_credit_Address(address to) public {
        // Fuzz test with different addresses including zero address
        // Handle zero address redirection
        address actualRecipient = (to == address(0)) ? address(0xdead) : to;
        uint256 initialBalance = rlcCrosschainToken.balanceOf(actualRecipient);

        // Expect the Transfer event to the actual recipient (0xdead if input was address(0))
        vm.expectEmit(true, true, true, true);
        emit IERC20.Transfer(address(0), actualRecipient, TRANSFER_AMOUNT);

        uint256 amountReceived = iexecLayerZeroBridgeChainX.exposed_credit(to, TRANSFER_AMOUNT, SOURCE_EID);

        assertEq(amountReceived, TRANSFER_AMOUNT, "Amount received should equal mint amount");
        assertEq(
            rlcCrosschainToken.balanceOf(actualRecipient),
            initialBalance + TRANSFER_AMOUNT,
            "Actual recipient balance should increase"
        );

        // Additional check for zero address case
        if (to == address(0)) {
            assertEq(rlcCrosschainToken.balanceOf(address(0)), 0, "Zero address balance should remain zero");
        }
    }

    function testFuzz_credit_Amount(uint256 amount) public {
        // Fuzz test with different amounts for testing edge case (0 & max RLC supply)
        vm.assume(amount <= INITIAL_BALANCE);
        uint256 initialBalance = rlcCrosschainToken.balanceOf(user2);
        uint256 amountReceived = iexecLayerZeroBridgeChainX.exposed_credit(user2, amount, SOURCE_EID);

        assertEq(amountReceived, amount, "Amount received should equal mint amount");
        assertEq(
            rlcCrosschainToken.balanceOf(user2), initialBalance + amount, "User balance should increase by mint amount"
        );
    }

    // function test_credit_RevertsWhenFullyPaused() public {
    //     // Test that _credit reverts when contract is fully paused
    //     uint256 mintAmount = TRANSFER_AMOUNT;

    //     // Pause the contract
    //     vm.prank(pauser);
    //     iexecLayerZeroBridgeChainX.pause();

    //     vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
    //     iexecLayerZeroBridgeChainX.exposed_credit(user2, mintAmount, SOURCE_EID);
    // }

    // function test_credit_WorksWhenOnlySendPaused() public {
    //     // Test that _credit still works when only sends are paused (Level 2 pause)
    //     uint256 mintAmount = TRANSFER_AMOUNT;
    //     uint256 initialBalance = rlcCrosschainToken.balanceOf(user2);

    //     // Pause only sends
    //     vm.prank(pauser);
    //     iexecLayerZeroBridgeChainX.pauseSend();

    //     vm.expectEmit(true, true, true, true);
    //     emit IERC20.Transfer(address(0), user2, mintAmount);

    //     uint256 amountReceived = iexecLayerZeroBridgeChainX.exposed_credit(user2, mintAmount, SOURCE_EID);

    //     assertEq(amountReceived, mintAmount, "Amount received should equal mint amount");
    //     assertEq(rlcCrosschainToken.balanceOf(user2), initialBalance + mintAmount, "User balance should increase");
    // }

    // function test_credit_WorksAfterUnpause() public {
    //     // Test that _credit works after unpausing
    //     uint256 mintAmount = TRANSFER_AMOUNT;
    //     uint256 initialBalance = rlcCrosschainToken.balanceOf(user2);

    //     // Pause the contract
    //     vm.prank(pauser);
    //     iexecLayerZeroBridgeChainX.pause();

    //     // Verify it's paused
    //     vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
    //     iexecLayerZeroBridgeChainX.exposed_credit(user2, mintAmount, SOURCE_EID);

    //     // Unpause the contract
    //     vm.prank(pauser);
    //     iexecLayerZeroBridgeChainX.unpause();

    //     // Now it should work
    //     vm.expectEmit(true, true, true, true);
    //     emit IERC20.Transfer(address(0), user2, mintAmount);

    //     uint256 amountReceived = iexecLayerZeroBridgeChainX.exposed_credit(user2, mintAmount, SOURCE_EID);

    //     assertEq(amountReceived, mintAmount, "Amount received should equal mint amount");
    //     assertEq(rlcCrosschainToken.balanceOf(user2), initialBalance + mintAmount, "User balance should increase");
    // }

    // ============ _debit ============
    // TODO:Add _debit tests
}
