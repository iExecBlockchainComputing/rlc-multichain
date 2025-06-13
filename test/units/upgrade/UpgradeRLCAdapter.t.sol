// SPDX-FileCopyrightText: 2025 IEXEC BLOCKCHAIN TECH <contact@iex.ec>
// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.22;

import {TestHelperOz5} from "@layerzerolabs/test-devtools-evm-foundry/contracts/TestHelperOz5.sol";
import {RLCAdapter} from "../../../src/RLCAdapter.sol";
import {RLCMock} from "../../units/mocks/RLCMock.sol";
import {RLCAdapterV2} from "../mocks/RLCAdapterV2Mock.sol";
import {TestUtils} from "./../utils/TestUtils.sol";
import {UpgradeUtils} from "../../../script/lib/UpgradeUtils.sol";

contract UpgradeRLCAdapterTest is TestHelperOz5 {
    using TestUtils for *;

    RLCAdapter public adapterV1;
    RLCAdapterV2 public adapterV2;
    RLCMock public rlcEthereumToken;
    // TODO use a common function to create addresses.
    address public mockEndpoint;
    address public owner = makeAddr("owner");
    address public pauser = makeAddr("pauser");
    address public proxyAddress;
    string public constant name = "RLC Ethereum Test";
    string public constant symbol = "RLC";
    uint256 public constant NEW_STATE_VARIABLE = 2;

    function setUp() public virtual override {
        super.setUp();
        setUpEndpoints(2, LibraryType.UltraLightNode);
        mockEndpoint = address(endpoints[1]);

        (adapterV1,, rlcEthereumToken,) =
            TestUtils.setupDeployment(name, symbol, mockEndpoint, mockEndpoint, owner, pauser);
        proxyAddress = address(adapterV1);
    }

    function test_UpgradeCorrectly() public {
        // 1. Verify V1 doesn't have V2 functions
        (bool success,) = proxyAddress.call(abi.encodeWithSignature("newStateVariable()"));
        assertFalse(success, "V1 should not have newStateVariable() function");

        (bool success2,) = proxyAddress.call(abi.encodeWithSignature("initializeV2(uint256)", 1000));
        assertFalse(success2, "V1 should not have initializeV2() function");

        // 2. Store V1 state for comparison
        address originalOwner = adapterV1.owner();
        address originalRlcToken = address(adapterV1.token());

        assertTrue(adapterV1.hasRole(adapterV1.DEFAULT_ADMIN_ROLE(), owner));
        assertTrue(adapterV1.hasRole(adapterV1.UPGRADER_ROLE(), owner));
        assertTrue(adapterV1.hasRole(adapterV1.PAUSER_ROLE(), pauser));

        // 3. Perform upgrade using UpgradeUtils directly
        vm.startPrank(owner);

        UpgradeUtils.UpgradeParams memory params = UpgradeUtils.UpgradeParams({
            proxyAddress: proxyAddress,
            contractName: "RLCAdapterV2Mock.sol:RLCAdapterV2",
            lzEndpoint: mockEndpoint,
            rlcToken: address(rlcEthereumToken),
            newStateVariable: NEW_STATE_VARIABLE,
            skipChecks: true, // Allow for testing with mocks
            validateOnly: false
        });

        UpgradeUtils.executeUpgrade(params);

        vm.stopPrank();

        adapterV2 = RLCAdapterV2(proxyAddress);

        // 5. Verify state preservation
        assertEq(adapterV2.owner(), originalOwner, "Owner should be preserved");
        assertEq(address(adapterV2.token()), originalRlcToken, "RLC token should be preserved");
        assertTrue(adapterV2.hasRole(adapterV2.DEFAULT_ADMIN_ROLE(), owner), "Default admin role should be preserved");
        assertTrue(adapterV2.hasRole(adapterV2.UPGRADER_ROLE(), owner), "Upgrader role should be preserved");
        assertTrue(adapterV2.hasRole(adapterV2.PAUSER_ROLE(), pauser), "Pauser role should be preserved");

        // 6. Verify new V2 functionality
        assertEq(adapterV2.newStateVariable(), NEW_STATE_VARIABLE, "New state variable should be initialized correctly");

        // 7. Verify V2 functions are now available
        (bool v2Success,) = proxyAddress.call(abi.encodeWithSignature("newStateVariable()"));
        assertTrue(v2Success, "V2 should have newStateVariable() function");
    }

    function test_RevertWhen_InitializeV2Twice() public {
        vm.startPrank(owner);

        UpgradeUtils.UpgradeParams memory params = UpgradeUtils.UpgradeParams({
            proxyAddress: proxyAddress,
            contractName: "RLCAdapterV2Mock.sol:RLCAdapterV2",
            lzEndpoint: mockEndpoint,
            rlcToken: address(rlcEthereumToken),
            newStateVariable: NEW_STATE_VARIABLE,
            skipChecks: true,
            validateOnly: false
        });

        UpgradeUtils.executeUpgrade(params);

        vm.stopPrank();

        adapterV2 = RLCAdapterV2(proxyAddress);

        // Verify it was initialized correctly
        assertEq(adapterV2.newStateVariable(), NEW_STATE_VARIABLE);

        // Attempt to initialize again should revert
        vm.prank(owner);
        vm.expectRevert();
        adapterV2.initializeV2(999); // Different value to ensure it's not a duplicate
    }
}
