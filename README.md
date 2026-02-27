 [![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
# BabyJubJub Solidity Library

Minimal Solidity implementation of core operations on the **BabyJubJub elliptic curve**.

## Install

Using Foundry:

```bash
forge install TaceoLabs/babyjubjub-solidity
```

## Usage

```solidity
import "babyjubjub-solidity/BabyJubJub.sol";

using BabyJubJub for BabyJubJub.Affine;
```

## Security

This library has been audited part of an larger audit. Since then we extracted this as a library to better use it in other projects. 

Audit reports can be found in `/audits`.