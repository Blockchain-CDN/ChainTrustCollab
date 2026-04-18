# Blockchain-Enabled Trust Management System

A Hardhat-based Solidity project implementing a trust evaluation system for industrial chain collaboration.

## Contracts

| Contract | Description |
|----------|-------------|
| `G_trust` | Trust management - stores collaboration history and calculates trust scores |
| `G_eval` | Collaboration lifecycle - handles request, join, confirm, complete |

## Run Tests

```shell
npx hardhat test
REPORT_GAS=true npx hardhat test
```
