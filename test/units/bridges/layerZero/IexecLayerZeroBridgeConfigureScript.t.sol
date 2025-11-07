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
import {UlnConfig} from "@layerzerolabs/lz-evm-messagelib-v2/contracts/uln/UlnBase.sol";
import {ExecutorConfig} from "@layerzerolabs/lz-evm-messagelib-v2/contracts/SendLibBase.sol";
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

interface IEndpointV2 {
    function delegates(address) external view returns (address);
}

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
    uint16 srcEndpointId = 1;
    uint16 dstEndpointId = 2;
    address srcEndpoint;
    address dstEndpoint;
    IexecLayerZeroBridge srcBridge;
    IexecLayerZeroBridge dstBridge;
    address srcBridgeAddress;
    address dstBridgeAddress;
    TestUtils.DeploymentResult deployment;

    function setUp() public virtual override {
        super.setUp();
        setUpEndpoints(2, LibraryType.UltraLightNode);
        srcEndpoint = endpoints[srcEndpointId];
        dstEndpoint = endpoints[dstEndpointId];
        deployment = TestUtils.setupDeployment(
            TestUtils.DeploymentParams({
                iexecLayerZeroBridgeContractName: "IexecLayerZeroBridge",
                lzEndpointSource: srcEndpoint,
                lzEndpointDestination: dstEndpoint,
                initialAdmin: admin,
                initialUpgrader: upgrader,
                initialPauser: pauser
            })
        );
        srcBridge = deployment.iexecLayerZeroBridgeWithApproval;
        dstBridge = deployment.iexecLayerZeroBridgeWithoutApproval;
        srcBridgeAddress = address(deployment.iexecLayerZeroBridgeWithApproval);
        dstBridgeAddress = address(deployment.iexecLayerZeroBridgeWithoutApproval);
        vm.startPrank(admin);
        srcBridge.setDelegate(delegate);
        console.log("src delegate:", IEndpointV2(srcEndpoint).delegates(address(srcBridgeAddress)));
        dstBridge.setDelegate(delegate);
        console.log("dst delegate:", IEndpointV2(dstEndpoint).delegates(address(dstBridgeAddress)));
        vm.stopPrank();
    }

    // // ====== configure ======

    // function test_configure_ShouldConfigureBridgeCorrectly() public {
    //     (ConfigLib.CommonConfigParams memory sourceParams, ConfigLib.CommonConfigParams memory targetParams) = _buildSourceAndTargetParams();
    //     vm.startPrank(admin);
    //     bool result = super.configure(sourceParams, targetParams);
    //     assertTrue(result, "Expected configure to return true");
    //     vm.stopPrank();
    // }

    // function test_configure_ShouldNotConfigureWhenAlreadyConfigured() public {
    //     (ConfigLib.CommonConfigParams memory sourceParams, ConfigLib.CommonConfigParams memory targetParams) = _buildSourceAndTargetParams();
    //     vm.startPrank(admin);
    //     // Configure bridge with the first call.
    //     bool firstCallResult = super.configure(sourceParams, targetParams);
    //     assertTrue(firstCallResult, "Expected configure to return true for the first call");
    //     // The second call does nothing.
    //     bool secondCallResult = super.configure(sourceParams, targetParams);
    //     assertFalse(secondCallResult, "Expected configure to return false for the second call");
    //     vm.stopPrank();
    // }

    // ====== setBridgePeerIfNeeded ======

    function _setBridgePeerIfNeeded_ShouldSetPeer() public {
        vm.startPrank(admin);
        vm.expectEmit(true, true, true, true, srcBridgeAddress);
        emit IOAppCore.PeerSet(dstEndpointId, addressToBytes32(dstBridgeAddress));
        bool result = super.setBridgePeerIfNeeded(srcBridgeAddress, dstEndpointId, dstBridgeAddress);
        assertTrue(result, "Expected setBridgePeerIfNeeded to return true");
        assertTrue(
            srcBridge.isPeer(dstEndpointId, addressToBytes32(dstBridgeAddress)), "Expected bridge to have the peer set"
        );
        vm.stopPrank();
    }

    function _setBridgePeerIfNeeded_ShouldOverridePeerWhenNewPeerIsDifferent() public {
        vm.startPrank(admin);
        bool result = super.setBridgePeerIfNeeded(srcBridgeAddress, dstEndpointId, dstBridgeAddress);
        assertTrue(result, "Expected setBridgePeerIfNeeded to return true");
        // Second call should override the peer.
        address randomAddress = makeAddr("random");
        bool secondCallResult = super.setBridgePeerIfNeeded(srcBridgeAddress, dstEndpointId, randomAddress);
        assertTrue(secondCallResult, "Expected setBridgePeerIfNeeded to return true for second call");
        assertFalse(
            srcBridge.isPeer(dstEndpointId, addressToBytes32(dstBridgeAddress)),
            "Expected bridge to not have the old peer"
        );
        assertTrue(
            srcBridge.isPeer(dstEndpointId, addressToBytes32(randomAddress)),
            "Expected bridge to have the peer overridden"
        );
        vm.stopPrank();
    }

    function _setBridgePeerIfNeeded_ShouldNotSetPeerWhenAlreadySet() public {
        vm.startPrank(admin);
        // First call should set the peer.
        bool firstCallResult = super.setBridgePeerIfNeeded(srcBridgeAddress, dstEndpointId, dstBridgeAddress);
        assertTrue(firstCallResult, "Expected setBridgePeerIfNeeded to return true for first call");
        // Second call should not change anything.
        bool secondCallResult = super.setBridgePeerIfNeeded(srcBridgeAddress, dstEndpointId, dstBridgeAddress);
        assertFalse(secondCallResult, "Expected setBridgePeerIfNeeded to return false for second call");
        vm.stopPrank();
    }

    // ====== setEnforcedOptionsIfNeeded ======

    function _setEnforcedOptionsIfNeeded_ShouldSetOptionsWhenEmpty() public {
        bytes memory options = LayerZeroUtils.buildLzReceiveExecutorConfig(GAS_LIMIT, 0);
        // TODO debug event emission.
        // vm.expectEmit(true, true, true, true, sourceBridgeAddress);
        // emit IOAppOptionsType3.EnforcedOptionSet(enforcedOptions);
        vm.startPrank(admin);
        bool result = super.setEnforcedOptionsIfNeeded(srcBridgeAddress, dstEndpointId);
        vm.stopPrank();
        assertTrue(result, "Expected setEnforcedOptionsIfNeeded to return true");
        bytes memory lzReceiveOnchainOptions =
            LayerZeroUtils.getOnchainLzReceiveEnforcedOptions(srcBridge, dstEndpointId);
        bytes memory lzComposeOnchainOptions =
            LayerZeroUtils.getOnchainLzComposeEnforcedOptions(srcBridge, dstEndpointId);
        assertEq(lzReceiveOnchainOptions, options, "lzReceive enforced options are not equal");
        assertEq(lzComposeOnchainOptions, options, "lzCompose enforced options are not equal");
    }

    function _setEnforcedOptionsIfNeeded_ShouldOverrideOptionsWhenNewOptionsAreDifferent() public {
        // 123456789 and 99 are different values from those set by the script.
        bytes memory oldOptions = LayerZeroUtils.buildLzReceiveExecutorConfig(123456789, 99);
        EnforcedOptionParam[] memory enforcedOptions = LayerZeroUtils.buildEnforcedOptions(dstEndpointId, oldOptions);
        vm.startPrank(admin);
        srcBridge.setEnforcedOptions(enforcedOptions);
        assertEq(
            LayerZeroUtils.getOnchainLzReceiveEnforcedOptions(srcBridge, dstEndpointId),
            oldOptions,
            "lzReceive enforced options are not equal"
        );
        assertEq(
            LayerZeroUtils.getOnchainLzComposeEnforcedOptions(srcBridge, dstEndpointId),
            oldOptions,
            "lzCompose enforced options are not equal"
        );
        // Second call should override the options.
        bytes memory newOptions = LayerZeroUtils.buildLzReceiveExecutorConfig(GAS_LIMIT, 0);
        bool result = super.setEnforcedOptionsIfNeeded(srcBridgeAddress, dstEndpointId);
        assertTrue(result, "Expected setEnforcedOptionsIfNeeded to return true");
        assertEq(
            LayerZeroUtils.getOnchainLzReceiveEnforcedOptions(srcBridge, dstEndpointId),
            newOptions,
            "lzReceive enforced options are not equal"
        );
        assertEq(
            LayerZeroUtils.getOnchainLzComposeEnforcedOptions(srcBridge, dstEndpointId),
            newOptions,
            "lzCompose enforced options are not equal"
        );
        vm.stopPrank();
    }

    function _setEnforcedOptionsIfNeeded_ShouldNotSetOptionsWhenAlreadySet() public {
        vm.startPrank(admin);
        bool firstCallResult = super.setEnforcedOptionsIfNeeded(srcBridgeAddress, dstEndpointId);
        assertTrue(firstCallResult, "Expected setEnforcedOptionsIfNeeded to return true");
        bool secondCallResult = super.setEnforcedOptionsIfNeeded(srcBridgeAddress, dstEndpointId);
        assertFalse(secondCallResult, "Expected setEnforcedOptionsIfNeeded to return false");
        vm.stopPrank();
    }

    // ====== setExecutorAndUlnConfigIfNeeded ======

    /**
     * In this test we read the default config, we change some values and we enforce it.
     * We cannot simply use random addresses for libraries, executor, and DVNs as they need
     * a lot of pre-configuration and they need to be registered in the test environment.
     * See `TestHelperOz5.createEndpoints` for more details.
     */
    function test_setExecutorAndUlnConfigIfNeeded_ShouldSetConfigWhenNotSet() public {
        LzConfig memory srcChainLzConfig = _buildLzConfigMock(srcEndpoint, srcBridgeAddress, dstEndpointId, 12);
        LzConfig memory dstChainLzConfig = _buildLzConfigMock(dstEndpoint, dstBridgeAddress, srcEndpointId, 34);
        vm.startPrank(delegate);
        // Make an external call using `this` for a better Foundry decoding.
        // LayerZeroUtils.setBridgeLzConfig(srcChainLzConfig, dstChainLzConfig);
        ILayerZeroEndpointV2(srcEndpoint)
            .setSendLibrary(srcChainLzConfig.bridge, dstChainLzConfig.endpointId, srcChainLzConfig.sendLibrary);
        // bool result = this.setExecutorAndUlnConfigIfNeeded(srcChainLzConfig, dstChainLzConfig);
        // assertTrue(result, "Expected setExecutorAndUlnConfigIfNeeded to return true");
        vm.stopPrank();
    }

    function read() public {
        uint32 ethereumSepoliaEid = 40161;
        uint32 arbitrumSepoliaEid = 40231;
        uint256 ethereumSepoliaFork = vm.createFork(vm.envString("SEPOLIA_RPC_URL"));
        uint256 arbitrumSepoliaFork = vm.createFork(vm.envString("ARBITRUM_SEPOLIA_RPC_URL"));
        console.log("################### Ethereum Sepolia config:");
        vm.selectFork(ethereumSepoliaFork);
        vm.startBroadcast();
        LayerZeroUtils.logBridgeLzConfig(
            LayerZeroUtils.getBridgeLzConfig(
                ILayerZeroEndpointV2(0x6EDCE65403992e310A62460808c4b910D972f10f),
                0xA18e571f91ab58889C348E1764fBaBF622ab89b5,
                ethereumSepoliaEid
            )
        );
        vm.stopBroadcast();
        vm.selectFork(arbitrumSepoliaFork);
        vm.startBroadcast();
        console.log("################### Arbitrum Sepolia config:");
        LayerZeroUtils.logBridgeLzConfig(
            LayerZeroUtils.getBridgeLzConfig(
                ILayerZeroEndpointV2(0x6EDCE65403992e310A62460808c4b910D972f10f),
                0xB560ae1dD7FdF011Ead2189510ae08f2dbD168a5,
                arbitrumSepoliaEid
            )
        );
        vm.stopBroadcast();
    }

    // ====== authorizeBridgeIfNeeded ======

    function _authorizeBridgeIfNeeded_ShouldAuthorizeBridge() public {
        vm.startPrank(admin);
        // rlcLiquidityUnifier
        assertTrue(
            super.authorizeBridgeIfNeeded(
                srcBridgeAddress,
                address(deployment.rlcLiquidityUnifier),
                deployment.rlcLiquidityUnifier.TOKEN_BRIDGE_ROLE()
            ),
            "Expected authorizeBridgeIfNeeded to return true"
        );
        assertTrue(
            deployment.rlcLiquidityUnifier
            .hasRole(deployment.rlcLiquidityUnifier.TOKEN_BRIDGE_ROLE(), srcBridgeAddress),
            "Expected bridge to have the role"
        );
        // rlcCrosschainToken
        assertTrue(
            super.authorizeBridgeIfNeeded(
                dstBridgeAddress,
                address(deployment.rlcCrosschainToken),
                deployment.rlcCrosschainToken.TOKEN_BRIDGE_ROLE()
            ),
            "Expected authorizeBridgeIfNeeded to return true"
        );
        assertTrue(
            deployment.rlcCrosschainToken.hasRole(deployment.rlcCrosschainToken.TOKEN_BRIDGE_ROLE(), dstBridgeAddress),
            "Expected bridge to have the role"
        );
        vm.stopPrank();
    }

    function _authorizeBridgeIfNeeded_ShouldNotAuthorizeBridgeIfAlreadyAuthorized() public {
        vm.startPrank(admin);
        assertTrue(
            super.authorizeBridgeIfNeeded(
                srcBridgeAddress,
                address(deployment.rlcLiquidityUnifier),
                deployment.rlcLiquidityUnifier.TOKEN_BRIDGE_ROLE()
            ),
            "Expected authorizeBridgeIfNeeded to return true"
        );
        assertTrue(
            deployment.rlcLiquidityUnifier
            .hasRole(deployment.rlcLiquidityUnifier.TOKEN_BRIDGE_ROLE(), srcBridgeAddress),
            "Expected bridge to have the role"
        );
        assertFalse(
            super.authorizeBridgeIfNeeded(
                srcBridgeAddress,
                address(deployment.rlcLiquidityUnifier),
                deployment.rlcLiquidityUnifier.TOKEN_BRIDGE_ROLE()
            ),
            "Expected authorizeBridgeIfNeeded to return false"
        );
        vm.stopPrank();
    }

    function _buildSourceAndTargetParams()
        private
        view
        returns (ConfigLib.CommonConfigParams memory, ConfigLib.CommonConfigParams memory)
    {
        // Source chain params
        ConfigLib.CommonConfigParams memory sourceParams;
        ConfigLib.CommonConfigParams memory targetParams;
        sourceParams.lzEndpointId = srcEndpointId;
        sourceParams.iexecLayerZeroBridgeAddress = srcBridgeAddress;
        sourceParams.approvalRequired = true;
        sourceParams.rlcLiquidityUnifierAddress = address(deployment.rlcLiquidityUnifier);
        sourceParams.rlcToken = address(deployment.rlcToken);
        // Target chain params
        targetParams.lzEndpointId = dstEndpointId;
        targetParams.iexecLayerZeroBridgeAddress = dstBridgeAddress;
        targetParams.approvalRequired = false;
        targetParams.rlcCrosschainTokenAddress = address(deployment.rlcCrosschainToken);
        return (sourceParams, targetParams);
    }

    function _buildLzConfigMock(address _srcEndpoint, address _srcBridge, uint32 _dstEndpointId, uint8 salt)
        private
        returns (LzConfig memory)
    {
        ILayerZeroEndpointV2 endpoint = ILayerZeroEndpointV2(_srcEndpoint);
        LzConfig memory defaultLzConfig = LayerZeroUtils.getBridgeLzConfig(endpoint, _srcBridge, _dstEndpointId);
        defaultLzConfig.executorConfig.maxMessageSize = salt;
        defaultLzConfig.executorConfig.executor = makeAddr(vm.toString(salt));
        defaultLzConfig.ulnConfig.confirmations = salt;
        defaultLzConfig.ulnConfig.requiredDVNCount = salt;
        defaultLzConfig.ulnConfig.optionalDVNCount = salt;
        defaultLzConfig.ulnConfig.optionalDVNThreshold = salt;
        return defaultLzConfig;
    }
}
