# RLC Layer Zero Bridge

This project implements a cross-chain token bridge for the RLC token between Ethereum and Arbitrum using LayerZero's OFT (Omnichain Fungible Token) protocol. It enables seamless token transfers between Ethereum Sepolia and Arbitrum Sepolia testnets.

## Architecture

The system consists of two main components:

1. **RLCAdapter (on Ethereum **Sepolia**)**: Wraps the existing RLC ERC-20 token to make it compatible with LayerZero's cross-chain messaging.
2. **RLCOFT (on Arbitrum Sepolia)**: A new token that's minted when RLC tokens are locked in the adapter on Ethereum, and burned when tokens are sent back.

[![Architecture Diagram](https://mermaid.ink/img/pako:eNqNVNtO4zAQ_RXLvAY2F3JpQEhpLrsPRUhQXqBoZRKXRjh2ZCdouf372nHSEhrYddV2MjnHZ-ZM4leYswLDED5wVG_AMllRIJdo73ViBdNmgzluK3CFa0ZKtIIaotblIr6VX7Bkj5ju0qflWXoZ2-bpj_LsbpeOClQ3mCtGH44oF9myT3_iLW5-p8tftwv0jPkN5gyktKhZSZseg2mhg73aI35fNny6dimnKpF_E-XL7H4R0eX8v4u4Fph3VasAMAoGG-_A4eHZmwWiuubsCQvQKHHxBkaWDPQObIMYESKAkBqfcP1FB3PAguWPuw1lc_ugY2kFLQSosBDoAb_15mqgjjucC2LOhDjMN6ikI7R0YYuWcYf2QIJJ-YT5h42lhRqnHFYgH5xLu3b1dT0qTweLhmnd7Rk56EQjJ_YU5mDecrpT2APEE91P9ZN82f2UV-lE919OKQPXlPx7Tj_BkiMq1mrTkWHbAvRvTpAQCV4DPLym65KQ8CD24izzDdFwSQ4PnMQ1576RM8J4eE9Q_njyiY-GV0Xz51bqZNmWb0eBnQXf8Vs1RM3NssSOzC03y4LANL_jkpeembjqs6u6WxPMD3xlnzE4N5jwUaAb_tDd6Mbgp7F9xlQTI4iestE_GuTlBBqwwrxCZSHPzFcFXUEpWuEVDGVY4DVqSaPOmXcJRW3Drp5pDkMpjg3Y1gVqcFIieUBVMFwjImS2RvSGsWoAyUsYvsI_MAysI8_yfNuZeY7tuUFgwGcYWjP3yLdN1_Jl5PiBab8b8KXbwDyaufbMOnYs27OsIPA8A3LWPmy2WrgoG8bP9ZnfHf2GPPpVN1qcy_cD85i1tJFKlj3UnHY8jXr_C5RA8AI?type=png)](https://mermaid.live/edit#pako:eNqNVNtO4zAQ_RXLvAY2F3JpQEhpLrsPRUhQXqBoZRKXRjh2ZCdouf372nHSEhrYddV2MjnHZ-ZM4leYswLDED5wVG_AMllRIJdo73ViBdNmgzluK3CFa0ZKtIIaotblIr6VX7Bkj5ju0qflWXoZ2-bpj_LsbpeOClQ3mCtGH44oF9myT3_iLW5-p8tftwv0jPkN5gyktKhZSZseg2mhg73aI35fNny6dimnKpF_E-XL7H4R0eX8v4u4Fph3VasAMAoGG-_A4eHZmwWiuubsCQvQKHHxBkaWDPQObIMYESKAkBqfcP1FB3PAguWPuw1lc_ugY2kFLQSosBDoAb_15mqgjjucC2LOhDjMN6ikI7R0YYuWcYf2QIJJ-YT5h42lhRqnHFYgH5xLu3b1dT0qTweLhmnd7Rk56EQjJ_YU5mDecrpT2APEE91P9ZN82f2UV-lE919OKQPXlPx7Tj_BkiMq1mrTkWHbAvRvTpAQCV4DPLym65KQ8CD24izzDdFwSQ4PnMQ1576RM8J4eE9Q_njyiY-GV0Xz51bqZNmWb0eBnQXf8Vs1RM3NssSOzC03y4LANL_jkpeembjqs6u6WxPMD3xlnzE4N5jwUaAb_tDd6Mbgp7F9xlQTI4iestE_GuTlBBqwwrxCZSHPzFcFXUEpWuEVDGVY4DVqSaPOmXcJRW3Drp5pDkMpjg3Y1gVqcFIieUBVMFwjImS2RvSGsWoAyUsYvsI_MAysI8_yfNuZeY7tuUFgwGcYWjP3yLdN1_Jl5PiBab8b8KXbwDyaufbMOnYs27OsIPA8A3LWPmy2WrgoG8bP9ZnfHf2GPPpVN1qcy_cD85i1tJFKlj3UnHY8jXr_C5RA8AI)

## Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation.html) for contract compilation and deployment
- Ethereum wallet with Sepolia ETH and Arbitrum Sepolia ETH for gas
- RLC tokens on Sepolia testnet for bridge testing

## Setup

1. Clone the repository
   ```bash
   git clone https://github.com/iExecBlockchainComputing/rlc-multichain.git
   cd rlc-multichain
   ```

2. Install dependencies
   ```bash
   forge install
   ```

3. Create a `.env` file
    ```sh
    cp .env.template .env # and edit .env content
    ```

## Deployment

The deployment process involves four steps:

1. Deploy the RLCAdapter on Ethereum Sepolia:
   ```bash
   make deploy-adapter
   ```

2. Deploy the RLCOFT on Arbitrum Sepolia:
   ```bash
   make deploy-oft
   ```

3. Configure the RLCAdapter to trust the RLCOFT contract:
   ```bash
   make conf-adapter
   ```

4. Configure the RLCOFT to trust the RLCAdapter contract:
   ```bash
   make conf-oft
   ```

After deployment, update your `.env` file with the deployed contract addresses.

## Usage

### Bridge RLC from Ethereum to Arbitrum

To send RLC tokens from Ethereum Sepolia to Arbitrum Sepolia:

```bash
make send-tokens
```

This will:
1. Approve the RLCAdapter to spend your RLC tokens
2. Initiate the cross-chain transfer through LayerZero
3. Lock tokens in the adapter and mint equivalent tokens on Arbitrum

### Bridge RLC from Arbitrum to Ethereum

To send RLC tokens from Arbitrum Sepolia back to Ethereum Sepolia:

```bash
make send-tokens-arbitrum-sepolia
```

This will:
1. Burn RLCOFT tokens on Arbitrum
2. Send a cross-chain message to the adapter
3. Release the original RLC tokens on Ethereum

## Contract Architecture

### RLCAdapter.sol

An adapter that wraps the existing RLC token to make it compatible with LayerZero's OFT protocol. It extends:
- `OFTAdapter`: Handles the OFT cross-chain logic
- `Ownable`: Provides ownership control for administrative functions

```solidity
contract RLCAdapter is Ownable, OFTAdapter {
    constructor(address _token, address _lzEndpoint, address _owner)
        OFTAdapter(_token, _lzEndpoint, _owner)
        Ownable(_owner)
    {}
}
```

### RLCOFT.sol

A new token on the destination chain (Arbitrum) that's minted when RLC tokens are locked in the adapter. It extends:
- `OFT`: Implements the OFT cross-chain logic
- `Ownable`: Provides ownership control for administrative functions

```solidity
contract RLCOFT is Ownable, OFT {
    constructor(string memory _name, string memory _symbol, address _lzEndpoint, address _delegate)
        OFT(_name, _symbol, _lzEndpoint, _delegate)
        Ownable(_delegate)
    {}

    function burn(uint256 _value) external returns (bool) {
        _burn(msg.sender, _value);
        return true;
    }

    function approveAndCall(address _spender, uint256 _value, bytes calldata _extraData) public returns (bool) {
        TokenSpender spender = TokenSpender(_spender);
        if (approve(_spender, _value)) {
            spender.receiveApproval(msg.sender, _value, address(this), _extraData);
            return true;
        }
        return false;
    }
}
```

## How It Works

1. **Ethereum → Arbitrum:**
   - User approves RLCAdapter to spend RLC tokens
   - RLCAdapter locks the RLC tokens
   - LayerZero delivers a message to RLCOFT
   - RLCOFT mints equivalent tokens to the recipient on Arbitrum

2. **Arbitrum → Ethereum:**
   - User initiates transfer from RLCOFT
   - RLCOFT burns the tokens
   - LayerZero delivers a message to RLCAdapter
   - RLCAdapter unlocks the original RLC tokens to the recipient on Ethereum

## Security Considerations

- The bridge security relies on LayerZero's security model
- Administrative functions are protected by the Ownable pattern
- Use caution when setting trusted remotes to prevent unauthorized cross-chain interactions

## Gas Costs and Fees

LayerZero transactions require fees to cover:
1. Gas on the source chain
2. Gas on the destination chain (prepaid)
3. LayerZero relayer fees

The scripts automatically calculate these fees and include them in the transaction.

## Testing

Testing with Foundry tests is recommended before mainnet deployments.

```bash
forge test
```

## Troubleshooting

Common issues:
- Insufficient gas: Ensure you have enough ETH on both networks
- Missing environment variables: Check your .env file is properly loaded
- Chain ID mismatch: Verify LayerZero chain IDs are correct

## References

- [LayerZero Documentation](https://layerzero.gitbook.io/docs/)
- [OFT Contracts](https://github.com/LayerZero-Labs/solidity-examples/tree/main/contracts/token/oft)