// SPDX-FileCopyrightText: 2025 IEXEC BLOCKCHAIN TECH <contact@iex.ec>
// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.22;

import {RLCOFT} from "../../../src/RLCOFT.sol";
import {RLCOFTV2} from "../../../src/mocks/RLCOFTV2Mock.sol";
import {TestUtils, TestUpgradeUtils} from "./../utils/TestUtils.sol";
import {UpgradeUtils} from "../../../script/lib/UpgradeUtils.sol";
import {TestHelperOz5} from "@layerzerolabs/test-devtools-evm-foundry/contracts/TestHelperOz5.sol";

contract UpgradeRLCOFTTest is TestHelperOz5 {
    using TestUtils for *;

    RLCOFT public oftV1;
    RLCOFTV2 public oftV2;
    address public mockEndpoint;
    address public owner = makeAddr("owner");
    address public pauser = makeAddr("pauser");

    address public proxyAddress;
    string public name = "RLC OFT Token";
    string public symbol = "RLC";
    uint256 public constant NEW_STATE_VARIABLE = 100000 * 10 ** 9;

    function setUp() public virtual override {
        super.setUp();
        setUpEndpoints(2, LibraryType.UltraLightNode);
        mockEndpoint = address(endpoints[1]);

        (, oftV1,) = TestUtils.setupDeployment(name, symbol, mockEndpoint, mockEndpoint, owner, pauser);
        proxyAddress = address(oftV1);
    }

    function test_V1DoesNotHaveV2Functions() public {
        // Test that V1 doesn't have V2 functions
        (bool success,) = proxyAddress.call(abi.encodeWithSignature("newStateVariable()"));
        assertFalse(success, "V1 should not have newStateVariable() function");

        (bool success2,) = proxyAddress.call(abi.encodeWithSignature("initializeV2(uint256)", 1000));
        assertFalse(success2, "V1 should not have initializeV2() function");
    }

    function test_UpgradeToV2() public {
        vm.startPrank(owner);
        
        TestUpgradeUtils.upgradeOFTForTesting(
            proxyAddress,
            "RLCOFTV2Mock.sol:RLCOFTV2",
            mockEndpoint,
            NEW_STATE_VARIABLE
        );
        
        vm.stopPrank();

        // Cast proxy to V2
        oftV2 = RLCOFTV2(proxyAddress);
    }

    function test_ValidateUpgrade() public {
        // Test that upgrade validation works
        TestUpgradeUtils.validateUpgradeForTesting(
            "RLCOFTV2Mock.sol:RLCOFTV2",
            mockEndpoint,
            UpgradeUtils.ContractType.OFT
        );
    }

    function test_V2StatePreservation() public {
        assertEq(oftV1.owner(), owner);
        assertTrue(oftV1.hasRole(oftV1.DEFAULT_ADMIN_ROLE(), owner));
        assertTrue(oftV1.hasRole(oftV1.UPGRADER_ROLE(), owner));
        assertTrue(oftV1.hasRole(oftV1.PAUSER_ROLE(), pauser));
        test_UpgradeToV2();

        // Test that original state is preserved
        assertEq(oftV2.name(), name, "Token name should be preserved");
        assertEq(oftV2.symbol(), symbol, "Token symbol should be preserved");
        assertEq(oftV2.decimals(), 9, "Decimals should be preserved");
        assertEq(oftV2.owner(), owner, "Owner should be preserved");
        assertTrue(oftV2.hasRole(oftV2.UPGRADER_ROLE(), owner), "Original upgrader role should be preserved");
        assertTrue(oftV2.hasRole(oftV2.PAUSER_ROLE(), pauser), "Original pauser role should be preserved");
    }

    function test_V2NewFunctionality() public {
        test_UpgradeToV2();

        // Test V2 version function
        string memory version = oftV2.version();
        assertEq(version, "2.0.0", "Version should be 2.0.0");

        // Test new state variable
        assertEq(oftV2.newStateVariable(), NEW_STATE_VARIABLE, "New state variable should be set correctly");
    }

    function test_RevertWhen_InitializeV2Twice() public {
        test_UpgradeToV2();

        // Test that initializeV2 cannot be called again
        vm.prank(owner);
        vm.expectRevert();
        oftV2.initializeV2(NEW_STATE_VARIABLE);
    }
}
