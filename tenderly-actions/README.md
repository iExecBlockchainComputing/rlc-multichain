# Tenderly Actions

This directory contains Tenderly Actions for monitoring and automating responses to blockchain events in the RLC Multichain project.

## 🚀 Quick Start

### Prerequisites

- Node.js installed
- Tenderly CLI installed (`npm install -g @tenderly/cli`)
- Tenderly account and project set up

### Installation

```bash
cd actions
npm install
```

### Deploy Actions

```bash
# Deploy all actions to Tenderly
npm run deploy
```

## ⚠️ Important Notes

- **Run Tenderly CLI commands**: All Tenderly CLI commands must be executed from the folder containing `tenderly.yaml`
- **File references**: All files referenced in actions must be within this `tenderly-actions/` directory
- **Simultaneous deployment**: All actions for a project are deployed together

## 📚 Documentation

- [Tenderly Actions Documentation](https://docs.tenderly.co/web3-actions/tutorials-and-quickstarts)
- [Tenderly CLI Reference](https://docs.tenderly.co/web3-actions/references/cli-cheatsheet)

## 🔧 Configuration

Edit `tenderly.yaml` to configure:

- Action triggers (events, blocks, etc.)
- Runtime settings
- Environment variables
- Project mappings
