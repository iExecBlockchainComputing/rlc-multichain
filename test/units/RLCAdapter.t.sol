// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {TestHelperOz5} from "@layerzerolabs/test-devtools-evm-foundry/contracts/TestHelperOz5.sol";
import {RLCMock} from "../units/mocks/RLCMock.sol";
import {Deploy as RLCAdapterDeploy} from "../units/mocks/RLCAdapterMock.sol";
import {RLCAdapter} from "../../src/RLCAdapter.sol";

contract RLCAdapterTest is TestHelperOz5, Initializable {
    RLCAdapter public rlcAdapter;
    RLCMock internal rlcToken;

    uint32 internal constant SOURCE_EID = 1;
    uint32 internal constant DEST_EID = 2;

    address owner = makeAddr("OWNER_ADDRESS");
    address pauser = makeAddr("PAUSER_ADDRESS");

    function setUp() public virtual override {
        super.setUp();
        setUpEndpoints(2, LibraryType.UltraLightNode);

        // Deploy RLC token mock
        rlcToken = new RLCMock("RLC OFT Test", "RLCT");

        // Set up endpoints for the deployment
        address lzEndpointAdapter = address(endpoints[SOURCE_EID]);

        rlcAdapter = RLCAdapter(new RLCAdapterDeploy().run(address(rlcToken), lzEndpointAdapter, owner, pauser));
    }

    function test_RevertWhenInitializingTwoTimes() public {
        vm.expectRevert(InvalidInitialization.selector);
        rlcAdapter.initialize(address(0xabcd));
    }
}
