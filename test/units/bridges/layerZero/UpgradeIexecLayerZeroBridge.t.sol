// SPDX-FileCopyrightText: 2025 IEXEC BLOCKCHAIN TECH <contact@iex.ec>
// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.22;

import {TestHelperOz5} from "@layerzerolabs/test-devtools-evm-foundry/contracts/TestHelperOz5.sol";
import {IexecLayerZeroBridgeV2} from "../../../../src/mocks/IexecLayerZeroBridgeV2Mock.sol";
import {TestUtils} from "./../../utils/TestUtils.sol";
import {RLCMock} from "../../mocks/RLCMock.sol";
import {UpgradeUtils} from "../../../../script/lib/UpgradeUtils.sol";
import {IexecLayerZeroBridge} from "../../../../src/bridges/layerZero/IexecLayerZeroBridge.sol";

contract UpgradeRLCOFTTest is TestHelperOz5 {
    using TestUtils for *;

    IexecLayerZeroBridge public iexecLayerZeroBridgeV1;
    IexecLayerZeroBridgeV2 public iexecLayerZeroBridgeV2;
    RLCMock private rlcCrosschainToken;

    address public mockEndpoint;
    address public owner = makeAddr("owner");
    address public pauser = makeAddr("pauser");

    address public proxyAddress;
    string public name = "RLC Crosschain Token";
    string public symbol = "RLC";
    uint256 public constant NEW_STATE_VARIABLE = 2;

    function setUp() public virtual override {
        super.setUp();
        setUpEndpoints(2, LibraryType.UltraLightNode);
        mockEndpoint = address(endpoints[1]);

        (, iexecLayerZeroBridgeV1,, rlcCrosschainToken) =
            TestUtils.setupDeployment(name, symbol, mockEndpoint, mockEndpoint, owner, pauser);
        proxyAddress = address(iexecLayerZeroBridgeV1);
    }

    function test_UpgradeCorrectly() public {
        // 1. Verify V1 doesn't have V2 functions
        (bool success,) = proxyAddress.call(abi.encodeWithSignature("newStateVariable()"));
        assertFalse(success, "V1 should not have newStateVariable() function");

        (bool success2,) = proxyAddress.call(abi.encodeWithSignature("initializeV2(uint256)", 1000));
        assertFalse(success2, "V1 should not have initializeV2() function");

        // 2. Store V1 state for comparison
        address originalOwner = iexecLayerZeroBridgeV1.owner();

        assertTrue(iexecLayerZeroBridgeV1.hasRole(iexecLayerZeroBridgeV1.DEFAULT_ADMIN_ROLE(), owner));
        assertTrue(iexecLayerZeroBridgeV1.hasRole(iexecLayerZeroBridgeV1.UPGRADER_ROLE(), owner));
        assertTrue(iexecLayerZeroBridgeV1.hasRole(iexecLayerZeroBridgeV1.PAUSER_ROLE(), pauser));

        // 3. Perform upgrade using UpgradeUtils directly
        vm.startPrank(owner);

        UpgradeUtils.UpgradeParams memory params = UpgradeUtils.UpgradeParams({
            proxyAddress: proxyAddress,
            contractName: "IexecLayerZeroBridgeV2Mock.sol:IexecLayerZeroBridgeV2",
            lzEndpoint: mockEndpoint,
            rlcToken: address(rlcCrosschainToken),
            newStateVariable: NEW_STATE_VARIABLE,
            validateOnly: false
        });

        UpgradeUtils.executeUpgrade(params);

        vm.stopPrank();

        iexecLayerZeroBridgeV2 = IexecLayerZeroBridgeV2(proxyAddress);

        // 5. Verify state preservation
        assertEq(iexecLayerZeroBridgeV2.owner(), originalOwner, "Owner should be preserved");
        assertTrue(
            iexecLayerZeroBridgeV2.hasRole(iexecLayerZeroBridgeV2.DEFAULT_ADMIN_ROLE(), owner),
            "Default admin role should be preserved"
        );
        assertTrue(
            iexecLayerZeroBridgeV2.hasRole(iexecLayerZeroBridgeV2.UPGRADER_ROLE(), owner),
            "Upgrader role should be preserved"
        );
        assertTrue(
            iexecLayerZeroBridgeV2.hasRole(iexecLayerZeroBridgeV2.PAUSER_ROLE(), pauser),
            "Pauser role should be preserved"
        );

        // 6. Verify new V2 functionality
        assertEq(
            iexecLayerZeroBridgeV2.newStateVariable(),
            NEW_STATE_VARIABLE,
            "New state variable should be initialized correctly"
        );

        // 7. Verify V2 functions are now available
        (bool v2Success,) = proxyAddress.call(abi.encodeWithSignature("newStateVariable()"));
        assertTrue(v2Success, "V2 should have newStateVariable() function");
    }

    function test_RevertWhen_InitializeV2Twice() public {
        vm.startPrank(owner);

        UpgradeUtils.UpgradeParams memory params = UpgradeUtils.UpgradeParams({
            proxyAddress: proxyAddress,
            contractName: "IexecLayerZeroBridgeV2Mock.sol:IexecLayerZeroBridgeV2",
            lzEndpoint: mockEndpoint,
            rlcToken: address(rlcCrosschainToken),
            newStateVariable: NEW_STATE_VARIABLE,
            validateOnly: false
        });

        UpgradeUtils.executeUpgrade(params);

        vm.stopPrank();

        iexecLayerZeroBridgeV2 = IexecLayerZeroBridgeV2(proxyAddress);

        // Verify it was initialized correctly
        assertEq(iexecLayerZeroBridgeV2.newStateVariable(), NEW_STATE_VARIABLE);

        // Attempt to initialize again should revert
        vm.prank(owner);
        vm.expectRevert();
        iexecLayerZeroBridgeV2.initializeV2(999); // Different value to ensure it's not a duplicate
    }
}
