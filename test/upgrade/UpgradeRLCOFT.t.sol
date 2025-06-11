// SPDX-FileCopyrightText: 2025 IEXEC BLOCKCHAIN TECH <contact@iex.ec>
// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.22;

import {Upgrades, Options} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {RLCOFT} from "../../src/RLCOFT.sol";
import {RLCOFTV2} from "../../src/mocks/RLCOFTV2Mock.sol";
import {TestUtils} from "./../units/utils/TestUtils.sol";
import {TestHelperOz5} from "@layerzerolabs/test-devtools-evm-foundry/contracts/TestHelperOz5.sol";

contract UpgradeRLCOFTTest is TestHelperOz5 {
    using TestUtils for *;

    RLCOFT public oftV1;
    RLCOFTV2 public oftV2;
    address public mockEndpoint;
    address public owner = makeAddr("owner");
    address public pauser = makeAddr("pauser");
    address public minter = makeAddr("minter");
    address public user = makeAddr("user");

    address public proxyAddress;
    string public name = "RLC OFT Token";
    string public symbol = "RLC";

    function setUp() public virtual override {
        super.setUp();
        setUpEndpoints(2, LibraryType.UltraLightNode);
        mockEndpoint = address(endpoints[1]);

        (, oftV1,) = TestUtils.setupDeployment(name, symbol, mockEndpoint, mockEndpoint, owner, pauser);
        proxyAddress = address(oftV1);
    }

    function testV1DoesNotHaveV2Functions() public {
        // Test that V1 doesn't have V2 functions
        (bool success,) = proxyAddress.call(abi.encodeWithSignature("version()"));
        assertFalse(success, "V1 should not have version() function");

        (bool success2,) = proxyAddress.call(abi.encodeWithSignature("setDailyMintLimit(uint256)", 1000));
        assertFalse(success2, "V1 should not have setDailyMintLimit() function");
    }

    function testUpgradeToV2() public {
        // Upgrade to V2
        vm.startPrank(owner);

        Options memory opts;
        opts.constructorData = abi.encode(mockEndpoint);
        // TODO: check why and how to fix it : opts.unsafeAllow
        opts.unsafeSkipAllChecks = true;

        bytes memory initData = abi.encodeWithSelector(RLCOFTV2.initializeV2.selector, minter, 100000 * 10 ** 9);

        Upgrades.upgradeProxy(proxyAddress, "RLCOFTV2Mock.sol:RLCOFTV2", initData, opts);

        vm.stopPrank();

        // Cast proxy to V2
        oftV2 = RLCOFTV2(proxyAddress);
    }

    function testV2StatePreservation() public {
        testUpgradeToV2();

        // Test that original state is preserved
        assertEq(oftV2.name(), name, "Token name should be preserved");
        assertEq(oftV2.symbol(), symbol, "Token symbol should be preserved");
        assertEq(oftV2.decimals(), 9, "Decimals should be preserved");
        assertEq(oftV2.owner(), owner, "Owner should be preserved");
        assertTrue(oftV2.hasRole(oftV2.UPGRADER_ROLE(), owner), "Original upgrader role should be preserved");
        assertTrue(oftV2.hasRole(oftV2.PAUSER_ROLE(), pauser), "Original pauser role should be preserved");
    }

    function testV2NewFunctionality() public {
        testUpgradeToV2();

        // Test V2 version function
        string memory version = oftV2.version();
        assertEq(version, "2.0.0", "Version should be 2.0.0");

        // Test V2 roles
        assertTrue(oftV2.hasRole(oftV2.MINTER_ROLE(), minter), "Minter role should be granted");

        // Test daily limit
        assertEq(oftV2.dailyMintLimit(), 100000 * 10 ** 9, "Daily mint limit should be set correctly");
    }

    function testV2SetDailyMintLimit() public {
        testUpgradeToV2();

        uint256 newLimit = 200000 * 10 ** 9;

        // Test setting daily mint limit by minter
        vm.prank(minter);
        oftV2.setDailyMintLimit(newLimit);

        assertEq(oftV2.dailyMintLimit(), newLimit, "Daily mint limit should be updated");
    }

    function testCannotInitializeV2Twice() public {
        testUpgradeToV2();

        // Test that initializeV2 cannot be called again
        vm.prank(owner);
        vm.expectRevert();
        oftV2.initializeV2(minter, 100000 * 10 ** 9);
    }
}
