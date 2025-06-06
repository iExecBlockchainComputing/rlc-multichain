// SPDX-FileCopyrightText: 2025 IEXEC BLOCKCHAIN TECH <contact@iex.ec>
// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.22;

import {Test, console} from "forge-std/Test.sol";
import {Upgrades, Options} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {RLCOFT} from "../../src/RLCOFT.sol";
import {RLCOFTV2} from "../../src/mocks/RLCOFTV2Mock.sol";

contract UpgradeRLCOFTTest is Test {
    RLCOFT public oftV1;
    RLCOFTV2 public oftV2;
    address public mockEndpoint = makeAddr("mockEndpoint"); 
    address public owner = makeAddr("owner");
    address public pauser = makeAddr("pauser");
    address public minter = makeAddr("minter");
    address public user = makeAddr("user");

    address public proxyAddress;
    string public constant TOKEN_NAME = "RLC OFT Test";
    string public constant TOKEN_SYMBOL = "RLCOFT";

    function setUp() public {
        // Deploy V1 using UUPS proxy
        Options memory opts;
        opts.constructorData = abi.encode(mockEndpoint);
        opts.unsafeSkipAllChecks = true;

        bytes memory initData = abi.encodeWithSelector(
            RLCOFT.initialize.selector,
            TOKEN_NAME,
            TOKEN_SYMBOL,
            owner,
            pauser
        );

        proxyAddress = Upgrades.deployUUPSProxy(
            "RLCOFT.sol:RLCOFT",
            initData,
            opts
        );

        oftV1 = RLCOFT(proxyAddress);
    }

    function testV1InitialState() public view {
        // Test V1 initial state

    }

    function testV1DoesNotHaveV2Functions() public {
        // Test that V1 doesn't have V2 functions
        vm.expectRevert();
        (bool success,) = proxyAddress.call(abi.encodeWithSignature("version()"));
        assertFalse(success);

        vm.expectRevert();
        (success,) = proxyAddress.call(abi.encodeWithSignature("setDailyMintLimit(uint256)", 1000));
        assertFalse(success);
    }

    function testUpgradeToV2() public {
        // Upgrade to V2
        vm.startPrank(owner);
        
        Options memory opts;
        opts.constructorData = abi.encode(mockEndpoint);
        opts.unsafeSkipAllChecks = true;

        bytes memory initData = abi.encodeWithSelector(
            RLCOFTV2.initializeV2.selector,
            minter,
            100000 * 10**9
        );

        Upgrades.upgradeProxy(
            proxyAddress,
            "RLCOFTV2.sol:RLCOFTV2",
            initData,
            opts
        );

        vm.stopPrank();

        // Cast proxy to V2
        oftV2 = RLCOFTV2(proxyAddress);
    }

    function testV2StatePreservation() public {
        testUpgradeToV2();

        // Test that original state is preserved
        assertEq(oftV2.name(), TOKEN_NAME, "Token name should be preserved");
        assertEq(oftV2.symbol(), TOKEN_SYMBOL, "Token symbol should be preserved");
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
        assertEq(oftV2.dailyMintLimit(), 100000 * 10**9, "Daily mint limit should be set correctly");
    }

    function testV2SetDailyMintLimit() public {
        testUpgradeToV2();

        uint256 newLimit = 200000 * 10**9;

        // Test setting daily mint limit by owner
        vm.prank(owner);
        oftV2.setDailyMintLimit(newLimit);

        assertEq(oftV2.dailyMintLimit(), newLimit, "Daily mint limit should be updated");
    }

    function testCannotInitializeV2Twice() public {
        testUpgradeToV2();

        // Test that initializeV2 cannot be called again
        vm.prank(owner);
        vm.expectRevert();
        oftV2.initializeV2(minter, 100000 * 10**9);
    }
}
