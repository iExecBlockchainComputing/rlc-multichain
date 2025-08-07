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
import {TestUtils} from "./../../utils/TestUtils.sol";
import {IexecLayerZeroBridge} from "../../../../src/bridges/layerZero/IexecLayerZeroBridge.sol";
import {RLCCrosschainToken} from "../../../../src/RLCCrosschainToken.sol";
import {Configure as IexecLayerZeroBridgeConfigureScript} from
    "../../../../script/bridges/layerZero/IexecLayerZeroBridge.s.sol";
import {ConfigLib} from "../../../../script/lib/ConfigLib.sol";
import {LayerZeroUtils} from "../../../../script/utils/LayerZeroUtils.sol";

// This test contract inherits from `Configure` script because we need the `msg.sender` to be the admin
// address (using vm.prank) when calling the `configure` function.
// Using `new IexecLayerZeroBridgeConfigureScript().configure(<params>)` sets the `msg.sender` to the
// wrong owner (the configurer contract).
contract IexecLayerZeroBridgeUpgradeScriptTest is TestHelperOz5, IexecLayerZeroBridgeConfigureScript {
    using TestUtils for *;

    address admin = makeAddr("admin");
    address upgrader = makeAddr("upgrader");
    address pauser = makeAddr("pauser");
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
    }

    function _configureSourceBridgeCorrectly() public {
        // Source chain params
        ConfigLib.CommonConfigParams memory sourceParams;
        sourceParams.lzEndpointId = sourceEndpointId;
        sourceParams.iexecLayerZeroBridgeAddress = sourceBridgeAddress;
        sourceParams.approvalRequired = true;
        sourceParams.rlcLiquidityUnifierAddress = address(deployment.rlcLiquidityUnifier);
        sourceParams.rlcToken = address(deployment.rlcToken);
        // Target chain params
        ConfigLib.CommonConfigParams memory targetParams;
        targetParams.lzEndpointId = targetEndpointId;
        targetParams.iexecLayerZeroBridgeAddress = targetBridgeAddress;
        targetParams.approvalRequired = false;
        targetParams.rlcCrosschainTokenAddress = address(deployment.rlcCrosschainToken);

        // Hardcoding 90_000 here to make sure tests fail when the value is changed in the script.
        bytes memory options = LayerZeroUtils.buildLzReceiveExecutorConfig(90_000, 0);
        EnforcedOptionParam[] memory enforcedOptions =
            LayerZeroUtils.buildEnforcedOptions(targetEndpointId, options);
        // Check that setPeer event is emitted.
        vm.expectEmit(true, true, true, true, sourceBridgeAddress);
        emit IOAppCore.PeerSet(targetEndpointId, addressToBytes32(targetBridgeAddress));
        // Check that setEnforcedOptions event is emitted.
        vm.expectEmit(true, true, true, true, sourceBridgeAddress);
        emit IOAppOptionsType3.EnforcedOptionSet(enforcedOptions);
        vm.startPrank(admin);
        super.configure(sourceParams, targetParams);
        vm.stopPrank();
    }

    function test_setBridgePeerIfNeeded_ShouldSetPeer() public {
        vm.startPrank(admin);
        vm.expectEmit(true, true, true, true, sourceBridgeAddress);
        emit IOAppCore.PeerSet(targetEndpointId, addressToBytes32(targetBridgeAddress));
        bool result = setBridgePeerIfNeeded(sourceBridgeAddress, targetEndpointId, targetBridgeAddress);
        assertTrue(result, "Expected setBridgePeerIfNeeded to return true");
        assertTrue(
            sourceBridge.isPeer(targetEndpointId, addressToBytes32(targetBridgeAddress)),
            "Expected bridge to have the peer set"
        );
        vm.stopPrank();
    }

    function test_setBridgePeerIfNeeded_ShouldOverridePeerWhenNewPeerIsDifferent() public {
        vm.startPrank(admin);
        bool result = setBridgePeerIfNeeded(sourceBridgeAddress, targetEndpointId, targetBridgeAddress);
        assertTrue(result, "Expected setBridgePeerIfNeeded to return true");
        // Second call should override the peer.
        address randomAddress = makeAddr("random");
        bool secondCallResult = setBridgePeerIfNeeded(sourceBridgeAddress, targetEndpointId, randomAddress);
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

    function test_setEnforcedOptionsIfNeeded_ShouldSetOptionsWhenEmpty() public {
        // Hardcoding 90_000 here to make sure tests fail when the value is changed in the script.
        bytes memory options = LayerZeroUtils.buildLzReceiveExecutorConfig(90_000, 0);
        // TODO debug event emission.
        // vm.expectEmit(true, true, true, true, sourceBridgeAddress);
        // emit IOAppOptionsType3.EnforcedOptionSet(enforcedOptions);
        vm.startPrank(admin);
        bool result = super.setEnforcedOptionsIfNeeded(sourceBridgeAddress, targetEndpointId);
        vm.stopPrank();
        assertTrue(result, "Expected setEnforcedOptionsIfNeeded to return true");
        bytes memory lzReceiveOnchainOptions = LayerZeroUtils.getOnchainLzReceiveEnforcedOptions(sourceBridge, targetEndpointId);
        bytes memory lzComposeOnchainOptions = LayerZeroUtils.getOnchainLzComposeEnforcedOptions(sourceBridge, targetEndpointId);
        assertEq(lzReceiveOnchainOptions, options, "lzReceive enforced options are not equal");
        assertEq(lzComposeOnchainOptions, options, "lzCompose enforced options are not equal");
    }

    function test_setEnforcedOptionsIfNeeded_ShouldOverrideOptionsWhenNewOptionsAreDifferent() public {
        // 123456789 and 99 are different values from those set by the script.
        bytes memory oldOptions = LayerZeroUtils.buildLzReceiveExecutorConfig(123456789, 99);
        EnforcedOptionParam[] memory enforcedOptions = LayerZeroUtils.buildEnforcedOptions(targetEndpointId, oldOptions);
        vm.startPrank(admin);
        sourceBridge.setEnforcedOptions(enforcedOptions);
        assertEq(LayerZeroUtils.getOnchainLzReceiveEnforcedOptions(sourceBridge, targetEndpointId), oldOptions, "lzReceive enforced options are not equal");
        assertEq(LayerZeroUtils.getOnchainLzComposeEnforcedOptions(sourceBridge, targetEndpointId), oldOptions, "lzCompose enforced options are not equal");
        // Second call should override the options.
        bytes memory newOptions = LayerZeroUtils.buildLzReceiveExecutorConfig(90_000, 0);
        bool result = super.setEnforcedOptionsIfNeeded(sourceBridgeAddress, targetEndpointId);
        assertTrue(result, "Expected setEnforcedOptionsIfNeeded to return true");
        assertEq(LayerZeroUtils.getOnchainLzReceiveEnforcedOptions(sourceBridge, targetEndpointId), newOptions, "lzReceive enforced options are not equal");
        assertEq(LayerZeroUtils.getOnchainLzComposeEnforcedOptions(sourceBridge, targetEndpointId), newOptions, "lzCompose enforced options are not equal");
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

    function test_authorizeBridgeIfNeeded_ShouldAuthorizeBridge() public {
        vm.startPrank(admin);
        bool result = super.authorizeBridgeIfNeeded(
            sourceBridgeAddress,
            address(deployment.rlcLiquidityUnifier),
            deployment.rlcLiquidityUnifier.TOKEN_BRIDGE_ROLE()
        );
        vm.stopPrank();
        assertTrue(result, "Expected authorizeBridgeIfNeeded to return true");
    }

    function test_authorizeBridgeIfNeeded_ShouldNotAuthorizeBridgeIfAlreadyAuthorized() public {
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
            deployment.rlcLiquidityUnifier.hasRole(deployment.rlcLiquidityUnifier.TOKEN_BRIDGE_ROLE(), sourceBridgeAddress),
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
            deployment.rlcCrosschainToken.hasRole(deployment.rlcCrosschainToken.TOKEN_BRIDGE_ROLE(), targetBridgeAddress),
            "Expected bridge to have the role"
        );
        vm.stopPrank();
    }

    function _abc() public {
        getConfig(
            vm.envString("SEPOLIA_RPC_URL"),
            0x6EDCE65403992e310A62460808c4b910D972f10f, // Endpoint
            0xA18e571f91ab58889C348E1764fBaBF622ab89b5, // OApp address
            0xcc1ae8Cf5D3904Cef3360A9532B477529b177cCE, // Message Library
            40231, // eid
            1 // Executor
        );
        getConfig(
            vm.envString("SEPOLIA_RPC_URL"),
            0x6EDCE65403992e310A62460808c4b910D972f10f, // Endpoint
            0xA18e571f91ab58889C348E1764fBaBF622ab89b5, // OApp address
            0xcc1ae8Cf5D3904Cef3360A9532B477529b177cCE, // Message Library
            40231, // eid
            2 // ULN
        );
    }

    /// @notice Calls getConfig on the specified LayerZero Endpoint.
    /// @dev Decodes the returned bytes as a UlnConfig. Logs some of its fields.
    /// @param _rpcUrl The RPC URL for the target chain.
    /// @param _endpoint The LayerZero Endpoint address.
    /// @param _oapp The address of your OApp.
    /// @param _lib The address of the Message Library (send or receive).
    /// @param _eid The remote endpoint identifier.
    /// @param _configType The configuration type (1 = Executor, 2 = ULN).
    function getConfig(
        string memory _rpcUrl,
        address _endpoint,
        address _oapp,
        address _lib,
        uint32 _eid,
        uint32 _configType
    ) public {
        // Create a fork from the specified RPC URL.
        vm.createSelectFork(_rpcUrl);
        vm.startBroadcast();

        // Instantiate the LayerZero endpoint.
        ILayerZeroEndpointV2 endpoint = ILayerZeroEndpointV2(_endpoint);
        // Retrieve the raw configuration bytes.
        bytes memory config = endpoint.getConfig(_oapp, _lib, _eid, _configType);

        if (_configType == 1) {
            console.log("###### Executor Config #####");
            // Decode the Executor config (configType = 1)
            ExecutorConfig memory execConfig = abi.decode(config, (ExecutorConfig));
            // Log some key configuration parameters.
            console.log("Executor Type:", execConfig.maxMessageSize);
            console.log("Executor Address:", execConfig.executor);
        }

        if (_configType == 2) {
            console.log("###### ULN Config #####");
            // Decode the ULN config (configType = 2)
            UlnConfig memory decodedConfig = abi.decode(config, (UlnConfig));
            // Log some key configuration parameters.
            console.log("Confirmations:", decodedConfig.confirmations);
            console.log("Required DVN Count:", decodedConfig.requiredDVNCount);
            for (uint256 i = 0; i < decodedConfig.requiredDVNs.length; i++) {
                console.log("[", i, "] Required DVN", decodedConfig.requiredDVNs[i]);
            }
            console.log("Optional DVN Count:", decodedConfig.optionalDVNCount);
            for (uint256 i = 0; i < decodedConfig.optionalDVNs.length; i++) {
                console.log("[", i, "] Optional DVN", decodedConfig.optionalDVNs[i]);
            }
            console.log("Optional DVN Threshold:", decodedConfig.optionalDVNThreshold);
        }
        vm.stopBroadcast();
    }
}
