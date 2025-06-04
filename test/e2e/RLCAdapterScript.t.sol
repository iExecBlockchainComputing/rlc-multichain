// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {Deploy as RLCAdapterDeploy} from "../../script/RLCAdapter.s.sol";
import {RLCAdapter} from "../../src/RLCAdapter.sol";

contract RLCAdapterScriptTest is Test {
    // Instance unique du script de déploiement
    address lzEndpoint = 0x6EDCE65403992e310A62460808c4b910D972f10f; // LayerZero Arbitrum Sepolia endpoint
    address owner = makeAddr("OWNER_ADDRESS");
    address rlcToken = 0x26A738b6D33EF4D94FF084D3552961b8f00639Cd;
    address constant createXFactory = 0xba5Ed099633D3B313e4D5F7bdc1305d3c28ba5Ed;

    RLCAdapterDeploy public deployer;
    function setUp() public {
        vm.createSelectFork("https://ethereum-sepolia-rpc.publicnode.com"); // use public node
        deployer = new RLCAdapterDeploy();
    }

    /**
     * Deployment
     */
    function test_CheckDeployment() public {
        bytes32 salt = keccak256("RLCOFT_SALT");
        RLCAdapter rlcAdapter = RLCAdapter(deployer.deploy(lzEndpoint, owner, createXFactory, salt, rlcToken));

        assertEq(rlcAdapter.owner(), owner);
        assertEq(rlcAdapter.token(), rlcToken);
        // TODO check roles
    }
}
