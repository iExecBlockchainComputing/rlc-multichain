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

    ConfigLib.CommonConfigParams sourceParams;
    ConfigLib.CommonConfigParams targetParams;
    address sourceBridgeAddress;
    address targetBridgeAddress;

    function setUp() public virtual override {
        super.setUp();
        setUpEndpoints(2, LibraryType.UltraLightNode);
        address sourceEndpoint = endpoints[1];
        address targetEndpoint = endpoints[2];
        TestUtils.DeploymentResult memory deployment = TestUtils.setupDeployment(
            TestUtils.DeploymentParams({
                iexecLayerZeroBridgeContractName: "IexecLayerZeroBridge",
                lzEndpointSource: sourceEndpoint,
                lzEndpointDestination: targetEndpoint,
                initialAdmin: admin,
                initialUpgrader: upgrader,
                initialPauser: pauser
            })
        );
        // Source chain params
        sourceBridgeAddress = address(deployment.iexecLayerZeroBridgeWithApproval);
        sourceParams.lzEndpointId = 1;
        sourceParams.iexecLayerZeroBridgeAddress = sourceBridgeAddress;
        sourceParams.approvalRequired = true;
        sourceParams.rlcLiquidityUnifierAddress = address(deployment.rlcLiquidityUnifier);
        sourceParams.rlcToken = address(deployment.rlcToken);
        // Target chain params
        targetBridgeAddress = address(deployment.iexecLayerZeroBridgeWithoutApproval);
        targetParams.lzEndpointId = 2;
        targetParams.iexecLayerZeroBridgeAddress = targetBridgeAddress;
        targetParams.approvalRequired = false;
        targetParams.rlcCrosschainTokenAddress = address(deployment.rlcCrosschainToken);
    }

    function test_configureSourceBridgeCorrectly() public {
        bytes32 targetBridgeAddressInBytes32 = bytes32(uint256(uint160(targetBridgeAddress)));
        // Hardcoding 90_000 here to make sure tests fail when the value is changed in the script.
        bytes memory options = LayerZeroUtils.buildLzReceiveExecutorConfig(90_000, 0);
        EnforcedOptionParam[] memory enforcedOptions =
            LayerZeroUtils.buildEnforcedOptions(targetParams.lzEndpointId, options);
        // Check that setPeer event is emitted.
        vm.expectEmit(true, true, true, true, sourceBridgeAddress);
        emit IOAppCore.PeerSet(targetParams.lzEndpointId, targetBridgeAddressInBytes32);
        // Check that setEnforcedOptions event is emitted.
        vm.expectEmit(true, true, true, true, sourceBridgeAddress);
        emit IOAppOptionsType3.EnforcedOptionSet(enforcedOptions);
        vm.startPrank(admin);
        super.configure(sourceParams, targetParams);
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
