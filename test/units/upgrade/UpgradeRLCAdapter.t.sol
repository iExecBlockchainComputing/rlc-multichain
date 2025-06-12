// SPDX-FileCopyrightText: 2025 IEXEC BLOCKCHAIN TECH <contact@iex.ec>
// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.22;

import {Upgrades, Options} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {RLCAdapter} from "../../../src/RLCAdapter.sol";
import {RLCMock} from "../../units/mocks/RLCMock.sol";
import {RLCAdapterV2} from "../../../src/mocks/RLCAdapterV2Mock.sol";
import {TestUtils} from "./../utils/TestUtils.sol";
import {TestHelperOz5} from "@layerzerolabs/test-devtools-evm-foundry/contracts/TestHelperOz5.sol";

contract UpgradeRLCAdapterTest is TestHelperOz5 {
    using TestUtils for *;

    RLCAdapter public adapterV1;
    RLCAdapterV2 public adapterV2;
    RLCMock public rlcToken;
    // TODO use a common function to create addresses.
    address public mockEndpoint;
    address public owner = makeAddr("owner");
    address public pauser = makeAddr("pauser");
    address public user = makeAddr("user");
    string public constant name = "RLC OFT Test";
    string public constant symbol = "RLCOFT";

    address public proxyAddress;

    function setUp() public virtual override {
        super.setUp();
        setUpEndpoints(2, LibraryType.UltraLightNode);
        mockEndpoint = address(endpoints[1]);

        (adapterV1,, rlcToken) = TestUtils.setupDeployment(name, symbol, mockEndpoint, mockEndpoint, owner, pauser);
        proxyAddress = address(adapterV1);
    }

    function test_V1DoesNotHaveV2Functions() public {
        // Test that V1 doesn't have V2 functions
        (bool success,) = proxyAddress.call(abi.encodeWithSignature("version()"));
        assertFalse(success, "V1 should not have version() function");

        (bool success2,) = proxyAddress.call(abi.encodeWithSignature("initializeV2(uint256)", 1000));
        assertFalse(success2, "V1 should not have initializeV2() function");
    }

    function test_UpgradeToV2() public {
        // Upgrade to V2
        vm.startPrank(owner);

        Options memory opts;
        opts.constructorData = abi.encode(address(rlcToken), mockEndpoint);
        // TODO: check why and how to fix it : opts.unsafeAllow
        opts.unsafeSkipAllChecks = true;

        bytes memory initData = abi.encodeWithSelector(
            RLCAdapterV2.initializeV2.selector,
            1000000 * 10 ** 18 // dailyLimit
        );

        Upgrades.upgradeProxy(proxyAddress, "RLCAdapterV2Mock.sol:RLCAdapterV2", initData, opts);

        vm.stopPrank();

        // Cast proxy to V2
        adapterV2 = RLCAdapterV2(proxyAddress);
    }

    function test_V2StatePreservation() public {
        // Check V1 state before upgrade
        assertEq(adapterV1.owner(), owner);
        assertTrue(adapterV1.hasRole(adapterV1.UPGRADER_ROLE(), owner));
        assertTrue(adapterV1.hasRole(adapterV1.PAUSER_ROLE(), pauser));

        test_UpgradeToV2();

        // Test that original state is preserved
        assertEq(adapterV2.owner(), owner, "Owner should be preserved");
        assertTrue(adapterV2.hasRole(adapterV2.UPGRADER_ROLE(), owner), "UPGRADER_ROLE should be preserved");
        assertTrue(adapterV2.hasRole(adapterV2.PAUSER_ROLE(), pauser), "PAUSER_ROLE should be preserved");
    }

    function test_V2NewFunctionality() public {
        test_UpgradeToV2();

        // Test V2 version function
        string memory version = adapterV2.version();
        assertEq(version, "2.0.0", "Version should be 2.0.0");

        // Test new state variable
        assertEq(adapterV2.newStateVariable(), 1000000 * 10 ** 18, "New state variable should be set");
    }

    function test_RevertWhen_InitializeV2Twice() public {
        test_UpgradeToV2();

        // Test that initializeV2 cannot be called again
        vm.prank(owner);
        vm.expectRevert();
        adapterV2.initializeV2(1000000 * 10 ** 18);
    }
}
