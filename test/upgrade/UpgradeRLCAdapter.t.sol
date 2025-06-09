// SPDX-FileCopyrightText: 2025 IEXEC BLOCKCHAIN TECH <contact@iex.ec>
// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.22;

import {Upgrades, Options} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {RLCAdapter} from "../../src/RLCAdapter.sol";
import {RLCMock} from "../units/mocks/RLCMock.sol";
import {RLCAdapterV2} from "../../src/mocks/RLCAdapterV2Mock.sol";
import {TestUtils} from "./../units/utils/TestUtils.sol";
import {TestHelperOz5} from "@layerzerolabs/test-devtools-evm-foundry/contracts/TestHelperOz5.sol";

contract UpgradeRLCAdapterTest is TestHelperOz5 {
    using TestUtils for *;

    RLCAdapter public adapterV1;
    RLCAdapterV2 public adapterV2;
    RLCMock public rlcToken;
    address public mockEndpoint = makeAddr("mockEndpoint");
    address public owner = makeAddr("owner");
    address public pauser = makeAddr("pauser");
    address public rateLimiter = makeAddr("rateLimiter");
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

    function testV1DoesNotHaveV2Functions() public {
        // Test that V1 doesn't have V2 functions
        (bool success,) = proxyAddress.call(abi.encodeWithSignature("version()"));
        assertFalse(success, "V1 should not have version() function");

        (bool success2,) = proxyAddress.call(abi.encodeWithSignature("setDailyTransferLimit(uint256)", 1000));
        assertFalse(success2, "V1 should not have setDailyTransferLimit() function");

        (bool success3,) =
            proxyAddress.call(abi.encodeWithSignature("initializeV2(uint256,address)", 1000, rateLimiter));
        assertFalse(success3, "V1 should not have initializeV2() function");
    }

    function testUpgradeToV2() public {
        // Upgrade to V2
        vm.startPrank(owner);

        Options memory opts;
        opts.constructorData = abi.encode(address(rlcToken), mockEndpoint);
        opts.unsafeSkipAllChecks = true;

        bytes memory initData = abi.encodeWithSelector(
            RLCAdapterV2.initializeV2.selector,
            rateLimiter, // rateLimiter address
            1000000 * 10 ** 18 // dailyLimit
        );

        Upgrades.upgradeProxy(proxyAddress, "RLCAdapterV2Mock.sol:RLCAdapterV2", initData, opts);

        vm.stopPrank();

        // Cast proxy to V2
        adapterV2 = RLCAdapterV2(proxyAddress);
    }

    function testV2StatePreservation() public {
        // Check V1 state before upgrade
        assertEq(adapterV1.owner(), owner);
        assertTrue(adapterV1.hasRole(adapterV1.UPGRADER_ROLE(), owner));
        assertTrue(adapterV1.hasRole(adapterV1.PAUSER_ROLE(), pauser));

        testUpgradeToV2();

        // Test that original state is preserved
        assertEq(adapterV2.owner(), owner, "Owner should be preserved");
        assertTrue(adapterV2.hasRole(adapterV2.UPGRADER_ROLE(), owner), "UPGRADER_ROLE should be preserved");
        assertTrue(adapterV2.hasRole(adapterV2.PAUSER_ROLE(), pauser), "PAUSER_ROLE should be preserved");
    }

    function testV2NewFunctionality() public {
        testUpgradeToV2();

        // Test V2 version function
        string memory version = adapterV2.version();
        assertEq(version, "2.0.0", "Version should be 2.0.0");

        // Test V2 roles
        assertTrue(adapterV2.hasRole(adapterV2.RATE_LIMITER_ROLE(), rateLimiter), "RATE_LIMITER_ROLE should be granted");

        // Test daily transfer limit
        assertEq(adapterV2.dailyTransferLimit(), 1000000 * 10 ** 18, "Daily transfer limit should be set");
    }

    function testV2TransferLimitUpdate() public {
        testUpgradeToV2();

        uint256 newLimit = 500000 * 10 ** 18;

        // Test setting transfer limit by rateLimiter
        vm.prank(rateLimiter);
        vm.expectEmit(true, false, false, true);
        emit RLCAdapterV2.DailyTransferLimitSet(newLimit);
        adapterV2.setDailyTransferLimit(newLimit);

        uint256 limit = adapterV2.dailyTransferLimit();
        assertEq(limit, newLimit, "Transfer limit should be updated");
    }

    function testCannotInitializeV2Twice() public {
        testUpgradeToV2();

        // Test that initializeV2 cannot be called again
        vm.prank(owner);
        vm.expectRevert();
        adapterV2.initializeV2(rateLimiter, 1000000 * 10 ** 18);
    }
}
