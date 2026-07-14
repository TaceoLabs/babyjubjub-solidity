 [![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
# BabyJubJub Solidity Library

Minimal Solidity implementation of core operations on the **BabyJubJub elliptic curve**.

## Install

Using Foundry:

```bash
forge install TaceoLabs/babyjubjub-solidity
```

Using [Soldeer](https://soldeer.xyz):

```bash
forge soldeer install babyjubjub-solidity~1.0.0
```

Or add it to your `foundry.toml`:
```toml
[dependencies]
babyjubjub-solidity = "1.0.0"
```

## Usage

```solidity
import "babyjubjub-solidity/BabyJubJub.sol";

using BabyJubJub for BabyJubJub.Affine;
```

Add one of the following to your `remappings.txt`, depending on how you installed the library:
```
# forge install
@taceo/babyjubjub/=lib/babyjubjub-solidity/src/

# Soldeer
@taceo/babyjubjub/=dependencies/babyjubjub-solidity-1.0.0/src/
```

## Security

This library has been audited part of an larger audit. Since then we extracted this as a library to better use it in other projects. 

Audit reports can be found in `/audits`.
