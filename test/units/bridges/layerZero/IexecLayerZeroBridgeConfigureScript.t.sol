// SPDX-FileCopyrightText: 2025 IEXEC BLOCKCHAIN TECH <contact@iex.ec>
// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.22;

import {console} from "forge-std/console.sol";
import {TestHelperOz5} from "@layerzerolabs/test-devtools-evm-foundry/contracts/TestHelperOz5.sol";
import {SendUln302Mock} from "@layerzerolabs/test-devtools-evm-foundry/contracts/mocks/SendUln302Mock.sol";
import {ReceiveUln302Mock} from "@layerzerolabs/test-devtools-evm-foundry/contracts/mocks/ReceiveUln302Mock.sol";
import {EndpointV2Mock} from "@layerzerolabs/test-devtools-evm-foundry/contracts/mocks/EndpointV2Mock.sol";
import {ILayerZeroEndpointV2} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import {UlnConfig} from "@layerzerolabs/lz-evm-messagelib-v2/contracts/uln/UlnBase.sol";
import {ExecutorConfig} from "@layerzerolabs/lz-evm-messagelib-v2/contracts/SendLibBase.sol";
import {IOAppCore} from "@layerzerolabs/oapp-evm/contracts/oapp/interfaces/IOAppCore.sol";
import {IOAppOptionsType3} from "@layerzerolabs/oapp-evm/contracts/oapp/interfaces/IOAppOptionsType3.sol";
import {EnforcedOptionParam} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OAppOptionsType3.sol";
import {SetConfigParam} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/IMessageLibManager.sol";
import {Errors} from "@layerzerolabs/lz-evm-protocol-v2/contracts/libs/Errors.sol";
import {TestUtils} from "./../../utils/TestUtils.sol";
import {IexecLayerZeroBridge} from "../../../../src/bridges/layerZero/IexecLayerZeroBridge.sol";
import {RLCCrosschainToken} from "../../../../src/RLCCrosschainToken.sol";
import {
    Configure as IexecLayerZeroBridgeConfigureScript
} from "../../../../script/bridges/layerZero/IexecLayerZeroBridge.s.sol";
import {ConfigLib} from "../../../../script/lib/ConfigLib.sol";
import {LayerZeroUtils} from "../../../../script/utils/LayerZeroUtils.sol";
import {LzConfig} from "../../../../script/lib/ConfigLib.sol";

// This test contract inherits from `Configure` script because we need the `msg.sender` to be the admin
// address (using vm.prank) when calling the `configure` function.
// Using `new IexecLayerZeroBridgeConfigureScript().configure(<params>)` sets the `msg.sender` to the
// wrong owner (the configurer contract).
contract IexecLayerZeroBridgeUpgradeScriptTest is TestHelperOz5, IexecLayerZeroBridgeConfigureScript {
    using TestUtils for *;

    // Hardcoding the value here to make sure tests fail when the value is changed in the script.
    uint128 constant GAS_LIMIT = 90_000;

    address admin = makeAddr("admin");
    address upgrader = makeAddr("upgrader");
    address pauser = makeAddr("pauser");
    address delegate = makeAddr("delegate");
    uint16 sourceEndpointId = 1;
    uint16 targetEndpointId = 2;
    address sourceEndpoint;
    address targetEndpoint;
    IexecLayerZeroBridge sourceBridge;
    IexecLayerZeroBridge targetBridge;
    address sourceBridgeAddress;
    address targetBridgeAddress;
    TestUtils.DeploymentResult deployment;

    function setUp() public virtual override {
        super.setUp();
        setUpEndpoints(2, LibraryType.UltraLightNode);
        sourceEndpoint = endpoints[sourceEndpointId];
        targetEndpoint = endpoints[targetEndpointId];
        deployment = TestUtils.setupDeployment(
            TestUtils.DeploymentParams({
                iexecLayerZeroBridgeContractName: "IexecLayerZeroBridge",
                lzEndpointSource: sourceEndpoint,
                lzEndpointDestination: targetEndpoint,
                initialAdmin: admin,
                initialUpgrader: upgrader,
                initialPauser: pauser
            })
        );
        sourceBridge = deployment.iexecLayerZeroBridgeWithApproval;
        targetBridge = deployment.iexecLayerZeroBridgeWithoutApproval;
        sourceBridgeAddress = address(deployment.iexecLayerZeroBridgeWithApproval);
        targetBridgeAddress = address(deployment.iexecLayerZeroBridgeWithoutApproval);
        vm.startPrank(admin);
        sourceBridge.setDelegate(delegate);
        targetBridge.setDelegate(delegate);
        vm.stopPrank();
    }

    // ====== configure ======
    // TODO add configure function tests.

    // ====== setBridgePeerIfNeeded ======

    function test_setBridgePeerIfNeeded_ShouldSetPeer() public {
        vm.startPrank(admin);
        vm.expectEmit(true, true, true, true, sourceBridgeAddress);
        emit IOAppCore.PeerSet(targetEndpointId, addressToBytes32(targetBridgeAddress));
        bool result = super.setBridgePeerIfNeeded(sourceBridgeAddress, targetEndpointId, targetBridgeAddress);
        assertTrue(result, "Expected setBridgePeerIfNeeded to return true");
        assertTrue(
            sourceBridge.isPeer(targetEndpointId, addressToBytes32(targetBridgeAddress)),
            "Expected bridge to have the peer set"
        );
        vm.stopPrank();
    }

    function test_setBridgePeerIfNeeded_ShouldOverridePeerWhenNewPeerIsDifferent() public {
        vm.startPrank(admin);
        bool result = super.setBridgePeerIfNeeded(sourceBridgeAddress, targetEndpointId, targetBridgeAddress);
        assertTrue(result, "Expected setBridgePeerIfNeeded to return true");
        // Second call should override the peer.
        address randomAddress = makeAddr("random");
        bool secondCallResult = super.setBridgePeerIfNeeded(sourceBridgeAddress, targetEndpointId, randomAddress);
        assertTrue(secondCallResult, "Expected setBridgePeerIfNeeded to return true for second call");
        assertFalse(
            sourceBridge.isPeer(targetEndpointId, addressToBytes32(targetBridgeAddress)),
            "Expected bridge to not have the old peer"
        );
        assertTrue(
            sourceBridge.isPeer(targetEndpointId, addressToBytes32(randomAddress)),
            "Expected bridge to have the peer overridden"
        );
        vm.stopPrank();
    }

    function test_setBridgePeerIfNeeded_ShouldNotSetPeerWhenAlreadySet() public {
        vm.startPrank(admin);
        // First call should set the peer.
        bool firstCallResult = super.setBridgePeerIfNeeded(sourceBridgeAddress, targetEndpointId, targetBridgeAddress);
        assertTrue(firstCallResult, "Expected setBridgePeerIfNeeded to return true for first call");
        // Second call should not change anything.
        bool secondCallResult = super.setBridgePeerIfNeeded(sourceBridgeAddress, targetEndpointId, targetBridgeAddress);
        assertFalse(secondCallResult, "Expected setBridgePeerIfNeeded to return false for second call");
        vm.stopPrank();
    }

    // ====== setEnforcedOptionsIfNeeded ======

    function test_setEnforcedOptionsIfNeeded_ShouldSetOptionsWhenEmpty() public {
        bytes memory options = LayerZeroUtils.buildLzReceiveExecutorConfig(GAS_LIMIT, 0);
        // TODO debug event emission.
        // vm.expectEmit(true, true, true, true, sourceBridgeAddress);
        // emit IOAppOptionsType3.EnforcedOptionSet(enforcedOptions);
        vm.startPrank(admin);
        bool result = super.setEnforcedOptionsIfNeeded(sourceBridgeAddress, targetEndpointId);
        vm.stopPrank();
        assertTrue(result, "Expected setEnforcedOptionsIfNeeded to return true");
        bytes memory lzReceiveOnchainOptions =
            LayerZeroUtils.getOnchainLzReceiveEnforcedOptions(sourceBridge, targetEndpointId);
        bytes memory lzComposeOnchainOptions =
            LayerZeroUtils.getOnchainLzComposeEnforcedOptions(sourceBridge, targetEndpointId);
        assertEq(lzReceiveOnchainOptions, options, "lzReceive enforced options are not equal");
        assertEq(lzComposeOnchainOptions, options, "lzCompose enforced options are not equal");
    }

    function test_setEnforcedOptionsIfNeeded_ShouldOverrideOptionsWhenNewOptionsAreDifferent() public {
        // 123456789 and 99 are different values from those set by the script.
        bytes memory oldOptions = LayerZeroUtils.buildLzReceiveExecutorConfig(123456789, 99);
        EnforcedOptionParam[] memory enforcedOptions = LayerZeroUtils.buildEnforcedOptions(targetEndpointId, oldOptions);
        vm.startPrank(admin);
        sourceBridge.setEnforcedOptions(enforcedOptions);
        assertEq(
            LayerZeroUtils.getOnchainLzReceiveEnforcedOptions(sourceBridge, targetEndpointId),
            oldOptions,
            "lzReceive enforced options are not equal"
        );
        assertEq(
            LayerZeroUtils.getOnchainLzComposeEnforcedOptions(sourceBridge, targetEndpointId),
            oldOptions,
            "lzCompose enforced options are not equal"
        );
        // Second call should override the options.
        bytes memory newOptions = LayerZeroUtils.buildLzReceiveExecutorConfig(GAS_LIMIT, 0);
        bool result = super.setEnforcedOptionsIfNeeded(sourceBridgeAddress, targetEndpointId);
        assertTrue(result, "Expected setEnforcedOptionsIfNeeded to return true");
        assertEq(
            LayerZeroUtils.getOnchainLzReceiveEnforcedOptions(sourceBridge, targetEndpointId),
            newOptions,
            "lzReceive enforced options are not equal"
        );
        assertEq(
            LayerZeroUtils.getOnchainLzComposeEnforcedOptions(sourceBridge, targetEndpointId),
            newOptions,
            "lzCompose enforced options are not equal"
        );
        vm.stopPrank();
    }

    function test_setEnforcedOptionsIfNeeded_ShouldNotSetOptionsWhenAlreadySet() public {
        vm.startPrank(admin);
        bool firstCallResult = super.setEnforcedOptionsIfNeeded(sourceBridgeAddress, targetEndpointId);
        assertTrue(firstCallResult, "Expected setEnforcedOptionsIfNeeded to return true");
        bool secondCallResult = super.setEnforcedOptionsIfNeeded(sourceBridgeAddress, targetEndpointId);
        assertFalse(secondCallResult, "Expected setEnforcedOptionsIfNeeded to return false");
        vm.stopPrank();
    }

    // ====== setExecutorAndUlnConfigIfNeeded ======

    function test_setExecutorAndUlnConfigIfNeeded_ShouldSetConfigWhenNotSet() public {
        LzConfig memory sourceChainLzConfig = _buildLzConfigMock(sourceEndpoint, sourceBridgeAddress, targetEndpointId);
        LzConfig memory targetChainLzConfig = _buildLzConfigMock(targetEndpoint, targetBridgeAddress, sourceEndpointId);
        vm.startPrank(delegate);
        bool result = setExecutorAndUlnConfigIfNeeded(sourceChainLzConfig, targetChainLzConfig);
        assertTrue(result, "Expected setExecutorAndUlnConfigIfNeeded to return true");
        vm.stopPrank();
    }

    // TODO implement other tests.

    // ====== authorizeBridgeIfNeeded ======

    function test_authorizeBridgeIfNeeded_ShouldAuthorizeBridge() public {
        vm.startPrank(admin);
        // rlcLiquidityUnifier
        assertTrue(
            super.authorizeBridgeIfNeeded(
                sourceBridgeAddress,
                address(deployment.rlcLiquidityUnifier),
                deployment.rlcLiquidityUnifier.TOKEN_BRIDGE_ROLE()
            ),
            "Expected authorizeBridgeIfNeeded to return true"
        );
        assertTrue(
            deployment.rlcLiquidityUnifier
                .hasRole(deployment.rlcLiquidityUnifier.TOKEN_BRIDGE_ROLE(), sourceBridgeAddress),
            "Expected bridge to have the role"
        );
        // rlcCrosschainToken
        assertTrue(
            super.authorizeBridgeIfNeeded(
                targetBridgeAddress,
                address(deployment.rlcCrosschainToken),
                deployment.rlcCrosschainToken.TOKEN_BRIDGE_ROLE()
            ),
            "Expected authorizeBridgeIfNeeded to return true"
        );
        assertTrue(
            deployment.rlcCrosschainToken
            .hasRole(deployment.rlcCrosschainToken.TOKEN_BRIDGE_ROLE(), targetBridgeAddress),
            "Expected bridge to have the role"
        );
        vm.stopPrank();
    }

    function test_authorizeBridgeIfNeeded_ShouldNotAuthorizeBridgeIfAlreadyAuthorized() public {
        vm.startPrank(admin);
        assertTrue(
            super.authorizeBridgeIfNeeded(
                sourceBridgeAddress,
                address(deployment.rlcLiquidityUnifier),
                deployment.rlcLiquidityUnifier.TOKEN_BRIDGE_ROLE()
            ),
            "Expected authorizeBridgeIfNeeded to return true"
        );
        assertTrue(
            deployment.rlcLiquidityUnifier
                .hasRole(deployment.rlcLiquidityUnifier.TOKEN_BRIDGE_ROLE(), sourceBridgeAddress),
            "Expected bridge to have the role"
        );
        assertFalse(
            super.authorizeBridgeIfNeeded(
                sourceBridgeAddress,
                address(deployment.rlcLiquidityUnifier),
                deployment.rlcLiquidityUnifier.TOKEN_BRIDGE_ROLE()
            ),
            "Expected authorizeBridgeIfNeeded to return false"
        );
        vm.stopPrank();
    }

    /**
     * Read the default config, change some values, then return the new config.
     * Library addresses cannot be changed because they need to be registered.
     * See `TestHelperOz5.createEndpoints` for more details.
     */
    function _buildLzConfigMock(address _sourceEndpoint, address _sourceBridge, uint32 _targetEndpointId)
        private
        returns (LzConfig memory)
    {
        ILayerZeroEndpointV2 endpoint = ILayerZeroEndpointV2(_sourceEndpoint);
        LzConfig memory lzConfig = LayerZeroUtils.getBridgeLzConfig(endpoint, _sourceBridge, _targetEndpointId);
        lzConfig.executorConfig.maxMessageSize = 123;
        lzConfig.executorConfig.executor = makeAddr("executor");
        lzConfig.ulnConfig.confirmations = 456;
        uint8 size = 3;
        lzConfig.ulnConfig.requiredDVNCount = size;
        lzConfig.ulnConfig.requiredDVNs = new address[](size);
        lzConfig.ulnConfig.requiredDVNs[0] = 0x00000000000000000000000000000000000000AA;
        lzConfig.ulnConfig.requiredDVNs[1] = 0x00000000000000000000000000000000000000bb;
        lzConfig.ulnConfig.requiredDVNs[2] = 0x00000000000000000000000000000000000000cc;
        lzConfig.ulnConfig.optionalDVNCount = size;
        lzConfig.ulnConfig.optionalDVNs = new address[](size);
        lzConfig.ulnConfig.optionalDVNs[0] = 0x00000000000000000000000000000000000000dd;
        lzConfig.ulnConfig.optionalDVNs[1] = 0x00000000000000000000000000000000000000eE;
        lzConfig.ulnConfig.optionalDVNs[2] = 0x00000000000000000000000000000000000000ff;
        lzConfig.ulnConfig.optionalDVNThreshold = size;
        return lzConfig;
    }
}
