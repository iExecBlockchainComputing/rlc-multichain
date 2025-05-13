## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

-   **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
-   **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
-   **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
-   **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

https://book.getfoundry.sh/

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```
forge script script/RLCAdapter.s.sol --rpc-url "https://lb.drpc.org/ogrpc?network=sepolia&dkey=AhEPbH3buE5zjj_dDMs3E2hIUihFGTAR8J88ThukG97E" --broadcast --account iexec-gabriel-mm-dev --verify -vvvv

forge script script/RLCOFT.s.sol --rpc-url "https://lb.drpc.org/ogrpc?network=arbitrum-sepolia&dkey=AhEPbH3buE5zjj_dDMs3E2hIUihFGTAR8J88ThukG97E" --broadcast --account iexec-gabriel-mm-dev --verify -vvvv

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```


forge script script/RLCAdapter.s.sol --rpc-url "https://lb.drpc.org/ogrpc?network=sepolia&dkey=AhEPbH3buE5zjj_dDMs3E2hIUihFGTAR8J88ThukG97E" --broadcast --account iexec-gabriel-mm-dev
Warning: This is a nightly build of Foundry. It is recommended to use the latest stable version. Visit https://book.getfoundry.sh/announcements for more information. 
To mute this warning set `FOUNDRY_DISABLE_NIGHTLY_WARNING` in your environment. 

[⠊] Compiling...
[⠒] Compiling 62 files with Solc 0.8.25
[⠢] Solc 0.8.25 finished in 1.08s
Compiler run successful!
Enter keystore password:
Script ran successfully.

## Setting up 1 EVM.

==========================

Chain 11155111

Estimated gas price: 0.001000044 gwei

Estimated total gas used for script: 5146876

Estimated amount required: 0.000005147102462544 ETH

==========================

##### sepolia
✅  [Success] Hash: 0x8866979e7ccd74306201da7e3816bfc6ef5788ffe2afd01dc1aeaed488418908
Contract Address: 0x3092c6B927d19B98967913756153Ea86B65774dC
Block: 8290001
Paid: 0.000003959227060128 ETH (3959136 gas * 0.001000023 gwei)

✅ Sequence #1 on sepolia | Total Paid: 0.000003959227060128 ETH (3959136 gas * avg 0.001000023 gwei)
                                                                                                                                                                                                                                                     

==========================

ONCHAIN EXECUTION COMPLETE & SUCCESSFUL.

Transactions saved to: /Users/gabriel/Documents/iexec/RLC-multichain/broadcast/RLCAdapter.s.sol/11155111/run-latest.json

Sensitive values saved to: /Users/gabriel/Documents/iexec/RLC-multichain/cache/RLCAdapter.s.sol/11155111/run-latest.json


forge script script/RLCOFT.s.sol --rpc-url "https://lb.drpc.org/ogrpc?network=arbitrum-sepolia&dkey=AhEPbH3buE5zjj_dDMs3E2hIUihFGTAR8J88ThukG97E" --broadcast --account iexec-gabriel-mm-dev --verify -vvvv
Warning: This is a nightly build of Foundry. It is recommended to use the latest stable version. Visit https://book.getfoundry.sh/announcements for more information. 
To mute this warning set `FOUNDRY_DISABLE_NIGHTLY_WARNING` in your environment. 

[⠊] Compiling...
[⠃] Compiling 1 files with Solc 0.8.25
[⠒] Solc 0.8.25 finished in 890.04ms
Compiler run successful!
Enter keystore password:
Traces:
  [4402550] DeployRLCOFT::run()
    ├─ [0] VM::startBroadcast()
    │   └─ ← [Return]
    ├─ [4353607] → new RLCOFT@0x15160ac50442CB2360A3917766e577fFeaE2FD23
    │   ├─ emit OwnershipTransferred(previousOwner: 0x0000000000000000000000000000000000000000, newOwner: DefaultSender: [0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38])
    │   ├─ [23959] 0x6EDCE65403992e310A62460808c4b910D972f10f::setDelegate(DefaultSender: [0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38])
    │   │   ├─ emit DelegateSet(sender: RLCOFT: [0x15160ac50442CB2360A3917766e577fFeaE2FD23], delegate: DefaultSender: [0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38])
    │   │   └─ ← [Stop]
    │   └─ ← [Return] 21246 bytes of code
    ├─ [0] VM::stopBroadcast()
    │   └─ ← [Return]
    └─ ← [Stop]


Script ran successfully.

## Setting up 1 EVM.
==========================
Simulated On-chain Traces:

  [4353607] → new RLCOFT@0x15160ac50442CB2360A3917766e577fFeaE2FD23
    ├─ emit OwnershipTransferred(previousOwner: 0x0000000000000000000000000000000000000000, newOwner: DefaultSender: [0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38])
    ├─ [23959] 0x6EDCE65403992e310A62460808c4b910D972f10f::setDelegate(DefaultSender: [0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38])
    │   ├─ emit DelegateSet(sender: RLCOFT: [0x15160ac50442CB2360A3917766e577fFeaE2FD23], delegate: DefaultSender: [0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38])
    │   └─ ← [Stop]
    └─ ← [Return] 21246 bytes of code


==========================

Chain 421614

Estimated gas price: 0.200000001 gwei

Estimated total gas used for script: 6260835

Estimated amount required: 0.001252167006260835 ETH

==========================

##### arbitrum-sepolia
✅  [Success] Hash: 0x23eaffd0ded6595787198c9d3fb14645082366c8856642d21d344b3c68056dc5
Contract Address: 0x15160ac50442CB2360A3917766e577fFeaE2FD23
Block: 151160367
Paid: 0.0004776947 ETH (4776947 gas * 0.1 gwei)

✅ Sequence #1 on arbitrum-sepolia | Total Paid: 0.0004776947 ETH (4776947 gas * avg 0.1 gwei)
                                                                                                                                                                                                                                                     

==========================

ONCHAIN EXECUTION COMPLETE & SUCCESSFUL.
##
Start verification for (1) contracts
Start verifying contract ****`0x15160ac50442CB2360A3917766e577fFeaE2FD23`**** deployed on arbitrum-sepolia
Compiler version: 0.8.25
Constructor args: 000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000c00000000000000000000000006edce65403992e310a62460808c4b910d972f10f0000000000000000000000001804c8ab1f12e6bbf3894d4083f33e07309d1f3800000000000000000000000000000000000000000000000000000000000000146945782e6563204e6574776f726b20546f6b656e0000000000000000000000000000000000000000000000000000000000000000000000000000000000000003524c430000000000000000000000000000000000000000000000000000000000
Attempting to verify on Sourcify, pass the --etherscan-api-key <API_KEY> to verify on Etherscan OR use the --verifier flag to verify on any other provider

Submitting verification for [RLCOFT] "0x15160ac50442CB2360A3917766e577fFeaE2FD23".
Contract successfully verified
All (1) contracts were verified!

Transactions saved to: /Users/gabriel/Documents/iexec/RLC-multichain/broadcast/RLCOFT.s.sol/421614/run-latest.json

Sensitive values saved to: /Users/gabriel/Documents/iexec/RLC-multichain/cache/RLCOFT.s.sol/421614/run-latest.json




RLC => 0x26A738b6D33EF4D94FF084D3552961b8f00639Cd
Sepolia => 0x83784F1233bA5c883F4a74ccB6b71991Cb442192 => adapter 
RLCAdapter deployed at: 0x83784F1233bA5c883F4a74ccB6b71991Cb442192

Sepolia ARBITRUM => 0x39BAeafdF85Ec5bBf3D00F7c27F0bc2F8e22ecD2 oft 
  RLCAdapter deployed at: 0x39BAeafdF85Ec5bBf3D00F7c27F0bc2F8e22ecD2


  forge script script/ConfigureRLCAdapter.s.sol --rpc-url "https://lb.drpc.org/ogrpc?network=sepolia&dkey=AhEPbH3buE5zjj_dDMs3E2hIUihFGTAR8J88ThukG97E" --broadcast --account iexec-gabriel-mm-dev

Warning: This is a nightly build of Foundry. It is recommended to use the latest stable version. Visit https://book.getfoundry.sh/announcements for more information. 
To mute this warning set `FOUNDRY_DISABLE_NIGHTLY_WARNING` in your environment. 

[⠊] Compiling...
[⠒] Compiling 1 files with Solc 0.8.25
[⠑] Solc 0.8.25 finished in 564.63ms
Compiler run successful!
Enter keystore password:
Script ran successfully.

## Setting up 1 EVM.

==========================

Chain 11155111

Estimated gas price: 0.001083598 gwei

Estimated total gas used for script: 66729

Estimated amount required: 0.000000072307410942 ETH

==========================

##### sepolia
✅  [Success] Hash: 0x2168df42fc4cee32cee8868ca1a24ab49f77e4e808fbad196caa0f8864933d60
Block: 8290509
Paid: 0.00000005234641783 ETH (48311 gas * 0.00108353 gwei)

✅ Sequence #1 on sepolia | Total Paid: 0.00000005234641783 ETH (48311 gas * avg 0.00108353 gwei)
                                                                                                                                                                                                                                                     

==========================

ONCHAIN EXECUTION COMPLETE & SUCCESSFUL.

Transactions saved to: /Users/gabriel/Documents/iexec/RLC-multichain/broadcast/ConfigureRLCAdapter.s.sol/11155111/run-latest.json

Sensitive values saved to: /Users/gabriel/Documents/iexec/RLC-multichain/cache/ConfigureRLCAdapter.s.sol/11155111/run-latest.json


forge script script/ConfigureRLCOFT.s.sol --rpc-url "https://lb.drpc.org/ogrpc?network=arbitrum-sepolia&dkey=AhEPbH3buE5zjj_dDMs3E2hIUihFGTAR8J88ThukG97E" --broadcast --account iexec-gabriel-mm-dev

Warning: This is a nightly build of Foundry. It is recommended to use the latest stable version. Visit https://book.getfoundry.sh/announcements for more information. 
To mute this warning set `FOUNDRY_DISABLE_NIGHTLY_WARNING` in your environment. 

[⠊] Compiling...
[⠑] Compiling 1 files with Solc 0.8.25
[⠘] Solc 0.8.25 finished in 635.67ms
Compiler run successful!
Enter keystore password:
Script ran successfully.

## Setting up 1 EVM.

==========================

Chain 421614

Estimated gas price: 0.200000001 gwei

Estimated total gas used for script: 63248

Estimated amount required: 0.000012649600063248 ETH

==========================

##### arbitrum-sepolia
✅  [Success] Hash: 0x07b959cbaf66d7333245676857832784396bc32264e5933b9e401342eb2ed36b
Block: 151182502
Paid: 0.0000048267 ETH (48267 gas * 0.1 gwei)

✅ Sequence #1 on arbitrum-sepolia | Total Paid: 0.0000048267 ETH (48267 gas * avg 0.1 gwei)
                                                                                                                                                                                                                                                     

==========================

ONCHAIN EXECUTION COMPLETE & SUCCESSFUL.

Transactions saved to: /Users/gabriel/Documents/iexec/RLC-multichain/broadcast/ConfigureRLCOFT.s.sol/421614/run-latest.json

Sensitive values saved to: /Users/gabriel/Documents/iexec/RLC-multichain/cache/ConfigureRLCOFT.s.sol/421614/run-latest.json