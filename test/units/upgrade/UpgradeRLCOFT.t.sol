// SPDX-FileCopyrightText: 2025 IEXEC BLOCKCHAIN TECH <contact@iex.ec>
// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.22;

import {RLCOFT} from "../../../src/RLCOFT.sol";
import {RLCOFTV2} from "./mocks/RLCOFTV2Mock.sol";
import {TestUtils} from "./../utils/TestUtils.sol";
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
    uint256 public constant NEW_STATE_VARIABLE = 2;

    function setUp() public virtual override {
        super.setUp();
        setUpEndpoints(2, LibraryType.UltraLightNode);
        mockEndpoint = address(endpoints[1]);

        (, oftV1,) = TestUtils.setupDeployment(name, symbol, mockEndpoint, mockEndpoint, owner, pauser);
        proxyAddress = address(oftV1);
    }

    function test_UpgradeCorrectly() public {
        // 1. Verify V1 doesn't have V2 functions
        (bool success,) = proxyAddress.call(abi.encodeWithSignature("newStateVariable()"));
        assertFalse(success, "V1 should not have newStateVariable() function");

        (bool success2,) = proxyAddress.call(abi.encodeWithSignature("initializeV2(uint256)", 1000));
        assertFalse(success2, "V1 should not have initializeV2() function");

        // 2. Store V1 state for comparison
        string memory originalName = oftV1.name();
        string memory originalSymbol = oftV1.symbol();
        uint8 originalDecimals = oftV1.decimals();
        address originalOwner = oftV1.owner();

        assertTrue(oftV1.hasRole(oftV1.DEFAULT_ADMIN_ROLE(), owner));
        assertTrue(oftV1.hasRole(oftV1.UPGRADER_ROLE(), owner));
        assertTrue(oftV1.hasRole(oftV1.PAUSER_ROLE(), pauser));

        // 3. Perform upgrade using UpgradeUtils directly
        vm.startPrank(owner);

        UpgradeUtils.UpgradeParams memory params = UpgradeUtils.UpgradeParams({
            proxyAddress: proxyAddress,
            contractName: "RLCOFTV2Mock.sol:RLCOFTV2",
            lzEndpoint: mockEndpoint,
            rlcToken: address(0), // Not used for OFT
            contractType: UpgradeUtils.ContractType.OFT,
            newStateVariable: NEW_STATE_VARIABLE,
            skipChecks: true, // Allow for testing with mocks
            validateOnly: false
        });

        UpgradeUtils.executeUpgradeOFT(params);

        vm.stopPrank();

        oftV2 = RLCOFTV2(proxyAddress);

        // 5. Verify state preservation
        assertEq(oftV2.name(), originalName, "Token name should be preserved");
        assertEq(oftV2.symbol(), originalSymbol, "Token symbol should be preserved");
        assertEq(oftV2.decimals(), originalDecimals, "Decimals should be preserved");
        assertEq(oftV2.owner(), originalOwner, "Owner should be preserved");
        assertTrue(oftV2.hasRole(oftV2.DEFAULT_ADMIN_ROLE(), owner), "Default admin role should be preserved");
        assertTrue(oftV2.hasRole(oftV2.UPGRADER_ROLE(), owner), "Upgrader role should be preserved");
        assertTrue(oftV2.hasRole(oftV2.PAUSER_ROLE(), pauser), "Pauser role should be preserved");

        // 6. Verify new V2 functionality
        assertEq(oftV2.newStateVariable(), NEW_STATE_VARIABLE, "New state variable should be initialized correctly");

        // 7. Verify V2 functions are now available
        (bool v2Success,) = proxyAddress.call(abi.encodeWithSignature("newStateVariable()"));
        assertTrue(v2Success, "V2 should have newStateVariable() function");
    }

    function test_RevertWhen_InitializeV2Twice() public {
        vm.startPrank(owner);

        UpgradeUtils.UpgradeParams memory params = UpgradeUtils.UpgradeParams({
            proxyAddress: proxyAddress,
            contractName: "RLCOFTV2Mock.sol:RLCOFTV2",
            lzEndpoint: mockEndpoint,
            rlcToken: address(0), // Not used for OFT
            contractType: UpgradeUtils.ContractType.OFT,
            newStateVariable: NEW_STATE_VARIABLE,
            skipChecks: true,
            validateOnly: false
        });

        UpgradeUtils.executeUpgradeOFT(params);

        vm.stopPrank();

        oftV2 = RLCOFTV2(proxyAddress);

        // Verify it was initialized correctly
        assertEq(oftV2.newStateVariable(), NEW_STATE_VARIABLE);

        // Attempt to initialize again should revert
        vm.prank(owner);
        vm.expectRevert();
        oftV2.initializeV2(999); // Different value to ensure it's not a duplicate
    }
}
