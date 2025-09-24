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
tenderly actions deploy

## ⚠️ Important Notes

- **Run commands from this directory**: All Tenderly commands must be executed from the folder containing `tenderly.yaml`
- **File references**: All files referenced in actions must be within this `tenderly-actions/` directory
- **Project selection**: If multiple Tenderly projects are configured, you'll be prompted to select one during deployment
- **Simultaneous deployment**: All actions for a project are deployed together

## 📚 Documentation

- [Tenderly Actions Documentation](https://docs.tenderly.co/actions)
- [Tenderly CLI Reference](https://docs.tenderly.co/tenderly-cli)

## 🔧 Configuration

Edit `tenderly.yaml` to configure:

- Action triggers (events, blocks, etc.)
- Runtime settings
- Environment variables
- Project mappings
