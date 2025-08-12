// SPDX-FileCopyrightText: 2025 IEXEC BLOCKCHAIN TECH <contact@iex.ec>
// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.22;

// import "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {TestHelperOz5} from "@layerzerolabs/test-devtools-evm-foundry/contracts/TestHelperOz5.sol";
import {ILayerZeroEndpointV2} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import {UlnConfig} from "@layerzerolabs/lz-evm-messagelib-v2/contracts/uln/UlnBase.sol";
import {ExecutorConfig} from "@layerzerolabs/lz-evm-messagelib-v2/contracts/SendLibBase.sol";
import {IOAppCore} from "@layerzerolabs/oapp-evm/contracts/oapp/interfaces/IOAppCore.sol";
import {IOAppOptionsType3} from "@layerzerolabs/oapp-evm/contracts/oapp/interfaces/IOAppOptionsType3.sol";
import {EnforcedOptionParam} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OAppOptionsType3.sol";
import {UlnConfig} from "@layerzerolabs/lz-evm-messagelib-v2/contracts/uln/UlnBase.sol";
import {ExecutorConfig} from "@layerzerolabs/lz-evm-messagelib-v2/contracts/SendLibBase.sol";
import {SetConfigParam} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/IMessageLibManager.sol";
import {ILayerZeroEndpointV2} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import {TestUtils} from "./../../utils/TestUtils.sol";
import {IexecLayerZeroBridge} from "../../../../src/bridges/layerZero/IexecLayerZeroBridge.sol";
import {RLCCrosschainToken} from "../../../../src/RLCCrosschainToken.sol";
import {Configure as IexecLayerZeroBridgeConfigureScript} from
    "../../../../script/bridges/layerZero/IexecLayerZeroBridge.s.sol";
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
    }

    // ====== configure ======

    function test_configure_ShouldConfigureBridgeCorrectly() public {
        (ConfigLib.CommonConfigParams memory sourceParams, ConfigLib.CommonConfigParams memory targetParams) = _buildSourceAndTargetParams();
        vm.startPrank(admin);
        bool result = super.configure(sourceParams, targetParams);
        assertTrue(result, "Expected configure to return true");
        vm.stopPrank();
    }

    function test_configure_ShouldNotConfigureWhenAlreadyConfigured() public {
        (ConfigLib.CommonConfigParams memory sourceParams, ConfigLib.CommonConfigParams memory targetParams) = _buildSourceAndTargetParams();
        vm.startPrank(admin);
        // Configure bridge with the first call.
        bool firstCallResult = super.configure(sourceParams, targetParams);
        assertTrue(firstCallResult, "Expected configure to return true for the first call");
        // The second call does nothing.
        bool secondCallResult = super.configure(sourceParams, targetParams);
        assertFalse(secondCallResult, "Expected configure to return false for the second call");
        vm.stopPrank();
    }

    // ====== setBridgePeerIfNeeded ======

    function test_setBridgePeerIfNeeded_ShouldSetPeer() public {
        vm.startPrank(admin);
        vm.expectEmit(true, true, true, true, srcBridgeAddress);
        emit IOAppCore.PeerSet(dstEndpointId, addressToBytes32(dstBridgeAddress));
        bool result = super.setBridgePeerIfNeeded(srcBridgeAddress, dstEndpointId, dstBridgeAddress);
        assertTrue(result, "Expected setBridgePeerIfNeeded to return true");
        assertTrue(
            srcBridge.isPeer(dstEndpointId, addressToBytes32(dstBridgeAddress)),
            "Expected bridge to have the peer set"
        );
        vm.stopPrank();
    }

    function test_setBridgePeerIfNeeded_ShouldOverridePeerWhenNewPeerIsDifferent() public {
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

    function test_setBridgePeerIfNeeded_ShouldNotSetPeerWhenAlreadySet() public {
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

    function test_setEnforcedOptionsIfNeeded_ShouldSetOptionsWhenEmpty() public {
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

    function test_setEnforcedOptionsIfNeeded_ShouldOverrideOptionsWhenNewOptionsAreDifferent() public {
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

    function test_setEnforcedOptionsIfNeeded_ShouldNotSetOptionsWhenAlreadySet() public {
        vm.startPrank(admin);
        bool firstCallResult = super.setEnforcedOptionsIfNeeded(srcBridgeAddress, dstEndpointId);
        assertTrue(firstCallResult, "Expected setEnforcedOptionsIfNeeded to return true");
        bool secondCallResult = super.setEnforcedOptionsIfNeeded(srcBridgeAddress, dstEndpointId);
        assertFalse(secondCallResult, "Expected setEnforcedOptionsIfNeeded to return false");
        vm.stopPrank();
    }

    // ====== setExecutorAndUlnConfigIfNeeded ======

    function test_setExecutorAndUlnConfigIfNeeded_ShouldSetConfigWhenNotSet() public {
        LzConfig memory srcChainLzConfig = _buildLzConfigMock(srcEndpoint, srcEndpointId, srcBridgeAddress, "src");
        LzConfig memory dstChainLzConfig = _buildLzConfigMock(dstEndpoint, dstEndpointId, dstBridgeAddress, "dst");
        vm.startPrank(admin);
        // Use this. to make an external call for better Foundry decoding.
        bool result = this.setExecutorAndUlnConfigIfNeeded(srcChainLzConfig, dstChainLzConfig);
        assertTrue(result, "Expected setExecutorAndUlnConfigIfNeeded to return true");
        vm.stopPrank();
    }

    function read() public {
        uint32 ethereumSepoliaEid = 40161;
        uint32 arbitrumSepoliaEid = 40231;
        address sendLib;
        address receiveLib;
        ExecutorConfig memory executorConfig;
        UlnConfig memory ulnConfig;
        uint ethereumSepoliaFork = vm.createFork(vm.envString("SEPOLIA_RPC_URL"));
        uint arbitrumSepoliaFork = vm.createFork(vm.envString("ARBITRUM_SEPOLIA_RPC_URL"));
        console.log("################### Ethereum Sepolia config:");
        vm.selectFork(ethereumSepoliaFork);
        vm.startBroadcast();
        (sendLib, receiveLib, executorConfig, ulnConfig) = LayerZeroUtils.getBridgeConfig(
            ILayerZeroEndpointV2(0x6EDCE65403992e310A62460808c4b910D972f10f),
            0xA18e571f91ab58889C348E1764fBaBF622ab89b5,
            ethereumSepoliaEid
        );
        vm.stopBroadcast();
        _logBridgeConfig(sendLib, receiveLib, executorConfig, ulnConfig);
        vm.selectFork(arbitrumSepoliaFork);
        vm.startBroadcast();
        console.log("################### Arbitrum Sepolia config:");
        (sendLib, receiveLib, executorConfig, ulnConfig) = LayerZeroUtils.getBridgeConfig(
            ILayerZeroEndpointV2(0x6EDCE65403992e310A62460808c4b910D972f10f),
            0xB560ae1dD7FdF011Ead2189510ae08f2dbD168a5,
            arbitrumSepoliaEid
        );
        _logBridgeConfig(sendLib, receiveLib, executorConfig, ulnConfig);
        vm.stopBroadcast();
    }

    // ====== authorizeBridgeIfNeeded ======

    function test_authorizeBridgeIfNeeded_ShouldAuthorizeBridge() public {
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
            deployment.rlcLiquidityUnifier.hasRole(
                deployment.rlcLiquidityUnifier.TOKEN_BRIDGE_ROLE(), srcBridgeAddress
            ),
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
            deployment.rlcCrosschainToken.hasRole(
                deployment.rlcCrosschainToken.TOKEN_BRIDGE_ROLE(), dstBridgeAddress
            ),
            "Expected bridge to have the role"
        );
        vm.stopPrank();
    }

    function test_authorizeBridgeIfNeeded_ShouldNotAuthorizeBridgeIfAlreadyAuthorized() public {
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
            deployment.rlcLiquidityUnifier.hasRole(
                deployment.rlcLiquidityUnifier.TOKEN_BRIDGE_ROLE(), srcBridgeAddress
            ),
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

    function _buildSourceAndTargetParams() private view returns (ConfigLib.CommonConfigParams memory, ConfigLib.CommonConfigParams memory) {
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

    function _buildLzConfigMock(address endpoint, uint32 endpointId, address bridge, string memory salt) private returns (LzConfig memory) {
        LzConfig memory lzConfig;
        lzConfig.endpointId = endpointId;
        lzConfig.endpoint = endpoint;
        lzConfig.bridge = bridge;
        lzConfig.sendLibrary = makeAddr(string.concat(salt, ".lzSendLibraryAddress"));
        lzConfig.receiveLibrary = makeAddr(string.concat(salt, ".lzReceiveLibraryAddress"));
        lzConfig.executorConfig = ExecutorConfig({
            executor: makeAddr(string.concat(salt, ".lzExecutorConfig.executor")),
            maxMessageSize: 10_000
        });
        lzConfig.ulnConfig = UlnConfig({
            confirmations: uint64(5),
            requiredDVNCount: uint8(2),
            requiredDVNs: new address[](2),
            optionalDVNCount: uint8(0),
            optionalDVNs: new address[](0),
            optionalDVNThreshold: uint8(0)
        });
        lzConfig.ulnConfig.requiredDVNs[0] = makeAddr(string.concat(salt, ".lzUlnConfig.requiredDVN1"));
        lzConfig.ulnConfig.requiredDVNs[1] = makeAddr(string.concat(salt, ".lzUlnConfig.requiredDVN2"));
        return lzConfig;
    }

    function _logBridgeConfig(
        address sendLib,
        address receiveLib,
        ExecutorConfig memory executorConfig,
        UlnConfig memory ulnConfig
    ) private pure {
        console.log("SendLib:", sendLib);
        console.log("ReceiveLib:", receiveLib);
        console.log("Executor maxMessageSize:", executorConfig.maxMessageSize);
        console.log("Executor address:", executorConfig.executor);
        console.log("Confirmations:", ulnConfig.confirmations);
        console.log("Required DVN Count:", ulnConfig.requiredDVNCount);
        for (uint256 i = 0; i < ulnConfig.requiredDVNs.length; i++) {
            console.log("[", i, "] Required DVN", ulnConfig.requiredDVNs[i]);
        }
        console.log("Optional DVN Count:", ulnConfig.optionalDVNCount);
        for (uint256 i = 0; i < ulnConfig.optionalDVNs.length; i++) {
            console.log("[", i, "] Optional DVN", ulnConfig.optionalDVNs[i]);
        }
        console.log("Optional DVN Threshold:", ulnConfig.optionalDVNThreshold);
    }
}
