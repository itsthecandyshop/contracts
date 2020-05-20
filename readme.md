
# Candy Store Lottery Contracts

This repository contains the core lottery contracts of Candy Store.
  

## Installation

1. Install Truffle and Ganache CLI globally.

```javascript
npm  install -g  truffle@beta
npm  install -g  ganache-cli
```

2. Install required packages.

```javascript
npm install
```

3. Create a `.env` file in the root directory and use the below format for .`env` file.

```javascript
infura_key = [Infura key] //For deploying
mnemonic_key = [Mnemonic Key] // Also called as seed key
etherscan_key = [Etherscan API dev Key]
```  

## Commands:

# Migrate:
```
truffle migrate --network=[network]
```

# To Verify Contracts on Etherscan:
```
truffle run verify [Contract_Name] --network=[network]
```
