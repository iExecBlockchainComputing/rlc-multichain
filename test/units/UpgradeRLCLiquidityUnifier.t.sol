// SPDX-FileCopyrightText: 2025 IEXEC BLOCKCHAIN TECH <contact@iex.ec>
// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.22;

import {TestHelperOz5} from "@layerzerolabs/test-devtools-evm-foundry/contracts/TestHelperOz5.sol";
import {RLCLiquidityUnifierV2} from "../../../../src/mocks/RLCLiquidityUnifierV2Mock.sol";
import {RLCLiquidityUnifier} from "../../../../src/RLCLiquidityUnifier.sol";
import {TestUtils} from "./utils/TestUtils.sol";
import {UpgradeUtils} from "../../../../script/lib/UpgradeUtils.sol";
import {IexecLayerZeroBridge} from "../../../../src/bridges/layerZero/IexecLayerZeroBridge.sol";
import {RLCMock} from "./mocks/RLCMock.sol";

contract UpgradeRLCLiquidityUnifier is TestHelperOz5 {
    using TestUtils for *;

    RLCLiquidityUnifier private rlcLiquidityUnifierV1;
    RLCLiquidityUnifierV2 private rlcLiquidityUnifierV2;
    RLCMock private rlcToken;

    address public mockEndpoint;
    address public admin = makeAddr("admin");
    address public pauser = makeAddr("pauser");
    address private upgrader = makeAddr("upgrader");

    address public proxyAddress;
    string private name = "iEx.ec Network Token";
    string public symbol = "RLC";
    uint256 public constant NEW_STATE_VARIABLE = 2;

    function setUp() public virtual override {
        super.setUp();
        setUpEndpoints(2, LibraryType.UltraLightNode);
        mockEndpoint = address(endpoints[1]);

        (,, rlcToken,, rlcLiquidityUnifierV1) =
            TestUtils.setupDeployment(name, symbol, mockEndpoint, mockEndpoint, admin, upgrader, pauser);
        proxyAddress = address(rlcLiquidityUnifierV1);
    }

    function test_UpgradeCorrectly() public {
        // 1. Verify V1 doesn't have V2 functions
        (bool success,) = proxyAddress.call(abi.encodeWithSignature("newStateVariable()"));
        assertFalse(success, "V1 should not have newStateVariable() function");

        (bool success2,) = proxyAddress.call(abi.encodeWithSignature("initializeV2(uint256)", 1000));
        assertFalse(success2, "V1 should not have initializeV2() function");

        // 2. Store V1 state for comparison
        address originalOwner = rlcLiquidityUnifierV1.owner();

        assertTrue(rlcLiquidityUnifierV1.hasRole(rlcLiquidityUnifierV1.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(rlcLiquidityUnifierV1.hasRole(rlcLiquidityUnifierV1.UPGRADER_ROLE(), upgrader));

        // 3. Perform upgrade using UpgradeUtils directly
        vm.startPrank(upgrader);

        UpgradeUtils.UpgradeParams memory params = UpgradeUtils.UpgradeParams({
            proxyAddress: proxyAddress,
            constructorData: abi.encode(rlcToken),
            contractName: "RLCLiquidityUnifierV2Mock.sol:RLCLiquidityUnifierV2",
            newStateVariable: NEW_STATE_VARIABLE,
            validateOnly: false
        });

        UpgradeUtils.executeUpgrade(params);

        vm.stopPrank();

        rlcLiquidityUnifierV2 = RLCLiquidityUnifierV2(proxyAddress);

        // 5. Verify state preservation
        assertEq(rlcLiquidityUnifierV2.owner(), originalOwner, "Admin should be preserved");
        assertTrue(
            rlcLiquidityUnifierV2.hasRole(rlcLiquidityUnifierV2.DEFAULT_ADMIN_ROLE(), admin),
            "Default admin role should be preserved"
        );
        assertTrue(
            rlcLiquidityUnifierV2.hasRole(rlcLiquidityUnifierV2.UPGRADER_ROLE(), upgrader),
            "Upgrader role should be preserved"
        );

        // 6. Verify new V2 functionality
        assertEq(
            rlcLiquidityUnifierV2.newStateVariable(),
            NEW_STATE_VARIABLE,
            "New state variable should be initialized correctly"
        );

        // 7. Verify V2 functions are now available
        (bool v2Success,) = proxyAddress.call(abi.encodeWithSignature("newStateVariable()"));
        assertTrue(v2Success, "V2 should have newStateVariable() function");
    }

    function test_RevertWhen_InitializeV2Twice() public {
        vm.startPrank(upgrader);

        UpgradeUtils.UpgradeParams memory params = UpgradeUtils.UpgradeParams({
            proxyAddress: proxyAddress,
            constructorData: abi.encode(rlcToken),
            contractName: "RLCLiquidityUnifierV2Mock.sol:RLCLiquidityUnifierV2",
            newStateVariable: NEW_STATE_VARIABLE,
            validateOnly: false
        });

        UpgradeUtils.executeUpgrade(params);

        vm.stopPrank();

        rlcLiquidityUnifierV2 = RLCLiquidityUnifierV2(proxyAddress);

        // Verify it was initialized correctly
        assertEq(rlcLiquidityUnifierV2.newStateVariable(), NEW_STATE_VARIABLE);

        // Attempt to initialize again should revert
        vm.prank(upgrader);
        vm.expectRevert();
        rlcLiquidityUnifierV2.initializeV2(999); // Different value to ensure it's not a duplicate
    }
}
