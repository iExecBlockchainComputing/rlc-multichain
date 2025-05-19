// SPDX-FileCopyrightText: 2025 IEXEC BLOCKCHAIN TECH <contact@iex.ec>
// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.22;

import {OFTUpgradeable} from "@layerzerolabs/oft-evm-upgradeable/contracts/oft/OFTUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {AccessControlDefaultAdminRulesUpgradeable} from "@openzeppelin/contracts-upgradeable/access/extensions/AccessControlDefaultAdminRulesUpgradeable.sol";
import {ITokenSpender} from "src/ITokenSpender.sol";

/// @notice OFT is an ERC-20 token that extends the OFTCore contract.
contract RLCOFT is OFTUpgradeable, UUPSUpgradeable, AccessControlDefaultAdminRulesUpgradeable {
    // Upgrader Role RLCAdapter contracts.
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    // Bridge Minter Role required for minting RLC Token
    bytes32 public constant BRIDGE_ROLE = keccak256("BRIDGE_ROLE");

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address _lzEndpoint) OFTUpgradeable(_lzEndpoint) {
        _disableInitializers();
    }

    /// @notice Initializes the contract
    /// @param _name Name of the token
    /// @param _symbol Symbol of the token
    /// @param _delegate Address of the contract owner
    function initialize(string memory _name, string memory _symbol, address _delegate) public initializer {
        __OFT_init(_name, _symbol, _delegate);
        __Ownable_init(_delegate);
        __UUPSUpgradeable_init();
        __AccessControlDefaultAdminRules_init(0, _delegate);
        _grantRole(UPGRADER_ROLE, _delegate);
    }

    /// @notice Authorizes an upgrade to a new implementation
    /// @dev Can only be called by the owner
    /// @param newImplementation Address of the new implementation
    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyRole(UPGRADER_ROLE) {}

    /**
     * @dev Override the decimals function to return 9 instead of the default 18
     * @return The number of decimals used in the token
     */
    function decimals() public pure override returns (uint8) {
        return 9;
    }

    function burn(uint256 _value) external returns (bool) {
        _burn(msg.sender, _value);
        return true;
    }

    /**
     * Approve and then call the approved contract in a single tx
     */
    function approveAndCall(address _spender, uint256 _value, bytes calldata _extraData) public returns (bool) {
        ITokenSpender spender = ITokenSpender(_spender);
        if (approve(_spender, _value)) {
            spender.receiveApproval(msg.sender, _value, address(this), _extraData);
            return true;
        }
        return false;
    }
}
