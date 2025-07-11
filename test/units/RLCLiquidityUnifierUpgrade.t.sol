// SPDX-FileCopyrightText: 2025 IEXEC BLOCKCHAIN TECH <contact@iex.ec>
// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.22;

import {TestHelperOz5} from "@layerzerolabs/test-devtools-evm-foundry/contracts/TestHelperOz5.sol";
import {RLCLiquidityUnifierV2} from "../../src/mocks/RLCLiquidityUnifierV2Mock.sol";
import {RLCLiquidityUnifier} from "../../src/RLCLiquidityUnifier.sol";
import {TestUtils} from "./utils/TestUtils.sol";
import {UpgradeUtils} from "../../script/lib/UpgradeUtils.sol";
import {RLCMock} from "./mocks/RLCMock.sol";

contract RLCLiquidityUnifierUpgradeTest is TestHelperOz5 {
    using TestUtils for *;

    RLCLiquidityUnifier private rlcLiquidityUnifierV1;
    RLCLiquidityUnifierV2 private rlcLiquidityUnifierV2;
    RLCMock private rlcToken;

    address public mockEndpoint;
    address public admin = makeAddr("admin");
    address public pauser = makeAddr("pauser");
    address private upgrader = makeAddr("upgrader");

    address public proxyAddress;
    uint256 public constant NEW_STATE_VARIABLE = 2;

    function setUp() public virtual override {
        super.setUp();
        setUpEndpoints(2, LibraryType.UltraLightNode);
        mockEndpoint = address(endpoints[1]);

        TestUtils.DeploymentResult memory deploymentResult = TestUtils.setupDeployment(
            TestUtils.DeploymentParams({
                iexecLayerZeroBridgeContractName: "IexecLayerZeroBridge",
                lzEndpointSource: mockEndpoint,
                lzEndpointDestination: mockEndpoint,
                initialAdmin: admin,
                initialUpgrader: upgrader,
                initialPauser: pauser
            })
        );

        rlcToken = deploymentResult.rlcToken;
        rlcLiquidityUnifierV1 = deploymentResult.rlcLiquidityUnifier;

        proxyAddress = address(rlcLiquidityUnifierV1);

        //Add label to make logs more readable
        vm.label(address(rlcToken), "rlcToken");
        vm.label(proxyAddress, "rlcLiquidityUnifierV1");
        vm.label(address(rlcLiquidityUnifierV2), "rlcLiquidityUnifierV2");
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
            newStateVariable: NEW_STATE_VARIABLE
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
}
