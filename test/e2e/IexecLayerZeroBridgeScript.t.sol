// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {Deploy as IexecLayerZeroBridgeDeploy} from "../../script/bridges/layerZero/IexecLayerZeroBridge.s.sol";
import {IexecLayerZeroBridge} from "../../src/bridges/layerZero/IexecLayerZeroBridge.sol";
//TODO: To remove when RLC_ERC20 contract will be developed
import {RLCMock} from "../units/mocks/RLCMock.sol";

contract IexecLayerZeroBridgeScriptTest is Test {
    address LAYERZERO_ENDPOINT = 0x6EDCE65403992e310A62460808c4b910D972f10f; // LayerZero Arbitrum Sepolia endpoint
    address CREATEX = 0xba5Ed099633D3B313e4D5F7bdc1305d3c28ba5Ed;

    address owner = makeAddr("OWNER_ADDRESS");
    address pauser = makeAddr("PAUSER_ADDRESS");
    address rlcAddress; // This will be set to a mock token address for testing
    bytes32 salt = keccak256("salt");

    IexecLayerZeroBridgeDeploy public deployer;

    function setUp() public {
        vm.createSelectFork(vm.envString("ARBITRUM_SEPOLIA_RPC_URL"));
        deployer = new IexecLayerZeroBridgeDeploy();
        //TODO: To remove when RLC_ERC20 contract will be developed
        rlcAddress = address(new RLCMock("TokenChainX", "RLC"));
        vm.setEnv("CREATE_X_FACTORY", vm.toString(CREATEX));
    }

    function testFork_Deployment() public {
        IexecLayerZeroBridge iexecLayerZeroBridge =
            IexecLayerZeroBridge(deployer.deploy(rlcAddress, LAYERZERO_ENDPOINT, owner, pauser, salt));

        assertEq(iexecLayerZeroBridge.owner(), owner);
        assertEq(iexecLayerZeroBridge.token(), address(rlcAddress));
        // TODO check all roles.
        // TODO check that the contract is not paused by default.
        // TODO check that the contract has been initialized and cannot be re-initialized.
        // TODO check that the contract has the correct LayerZero endpoint.
        // TODO check that the proxy address is saved.
    }

    function testFork_RevertWhen_TwoDeploymentsWithTheSameSalt() public {
        deployer.deploy(rlcAddress, LAYERZERO_ENDPOINT, owner, pauser, salt);
        vm.expectRevert(abi.encodeWithSignature("FailedContractCreation(address)", CREATEX));
        deployer.deploy(rlcAddress, LAYERZERO_ENDPOINT, owner, pauser, salt);
    }

    // TODO add tests for the configuration script.

    function testFork_ConfigureContractCorrectly() public {
        // TODO check that the peer has been set with the correct config.
    }

    function testFork_RevertWhenPeerIsAlreadySet() public {}

    function testFork_RevertWhenAnyConfigurationVariableIsMissing() public {}
}
