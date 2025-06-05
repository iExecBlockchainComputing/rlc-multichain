// SPDX-FileCopyrightText: 2025 IEXEC BLOCKCHAIN TECH <contact@iex.ec>
// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.22;

import {Test, console} from "forge-std/Test.sol";
import {Upgrades, Options} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {RLCAdapter} from "../../src/RLCAdapter.sol";
import {RLCAdapterV2} from "../../src/mocks/RLCAdapterV2mock.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract UpgradeRLCAdapterTest is Test {
    RLCAdapter public adapterV1;
    RLCAdapterV2 public adapterV2;
    ERC20Mock public mockRLC;
    address public mockEndpoint;
    address public owner;
    address public operator;
    address public user;

    address public proxyAddress;

    function setUp() public {
        owner = makeAddr("owner");
        operator = makeAddr("operator");
        user = makeAddr("user");
        mockEndpoint = makeAddr("mockEndpoint");

        // Deploy mock RLC token
        vm.prank(owner);
        mockRLC = new ERC20Mock();

        // Deploy V1 using UUPS proxy
        Options memory opts;
        opts.constructorData = abi.encode(address(mockRLC), mockEndpoint);
        opts.unsafeSkipAllChecks = true;

        bytes memory initData = abi.encodeWithSelector(
            RLCAdapter.initialize.selector,
            owner
        );

        proxyAddress = Upgrades.deployUUPSProxy(
            "RLCAdapter.sol:RLCAdapter",
            initData,
            opts
        );

        adapterV1 = RLCAdapter(proxyAddress);
    }

    function testV1DoesNotHaveV2Functions() public {
        // Test that V1 doesn't have V2 functions
        vm.expectRevert();
        (bool success,) = proxyAddress.call(abi.encodeWithSignature("version()"));
        assertFalse(success);

        vm.expectRevert();
        (success,) = proxyAddress.call(abi.encodeWithSignature("setMaxTransferLimit(uint256)", 1000));
        assertFalse(success);
    }

    function testUpgradeToV2() public {
        // Upgrade to V2
        vm.startPrank(owner);
        
        Options memory opts;
        opts.constructorData = abi.encode(address(mockRLC), mockEndpoint);
        opts.unsafeSkipAllChecks = true;

        bytes memory initData = abi.encodeWithSelector(
            RLCAdapterV2.initializeV2.selector,
            operator,
            1000000 * 10**18  // 1M token max transfer limit
        );

        Upgrades.upgradeProxy(
            proxyAddress,
            "RLCAdapterV2.sol:RLCAdapterV2",
            initData,
            opts
        );

        vm.stopPrank();

        // Cast proxy to V2
        adapterV2 = RLCAdapterV2(proxyAddress);
    }

    function testV2StatePreservation() public {
        assertEq(adapterV1.owner(), owner);
        assertTrue(adapterV1.hasRole(adapterV1.UPGRADER_ROLE(), owner));

        testUpgradeToV2();

        // Test that original state is preserved
        assertEq(adapterV2.owner(), owner, "Owner should be preserved");
        assertTrue(adapterV2.hasRole(adapterV2.UPGRADER_ROLE(), owner), "Original roles should be preserved");
    }

    function testV2NewFunctionality() public {
        testUpgradeToV2();

        // Test V2 version function
        string memory version = adapterV2.version();
        assertEq(version, "2.0.0", "Version should be 2.0.0");

        // Test V2 roles
        assertTrue(adapterV2.hasRole(adapterV2.OPERATOR_ROLE(), operator), "Operator role should be granted");
    }

    function testV2TransferLimitUpdate() public {
        testUpgradeToV2();

        uint256 newLimit = 500000 * 10**18;

        // Test setting transfer limit by owner
        vm.prank(owner);
        vm.expectEmit(true, false, false, false);
        emit RLCAdapterV2.TransferLimitUpdated(newLimit);
        adapterV2.setMaxTransferLimit(newLimit);

        uint256 limit = adapterV2.maxTransferLimit();
        assertEq(limit, newLimit, "Transfer limit should be updated");
    }

    function testCannotInitializeV2Twice() public {
        testUpgradeToV2();

        // Test that initializeV2 cannot be called again
        vm.prank(owner);
        vm.expectRevert();
        adapterV2.initializeV2(operator, 1000000 * 10**18);
    }

}
