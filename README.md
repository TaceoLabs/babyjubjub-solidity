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

For an untrusted affine point, check the canonical coordinates and curve equation before using the gas-efficient subgroup check:

```solidity
require(BabyJubJub.isOnCurve(point));
require(BabyJubJub.isInCorrectSubgroupAssumingOnCurveTate(point));
```

The Tate-based check is `view` because it uses the EVM modular-exponentiation precompile at address `0x05`.
On chains without this precompile it reverts with `ModExpPrecompileFailed` on every call. The original pure
`isInCorrectSubgroupAssumingOnCurve` order-multiplication check remains available as a portable fallback that
works on any EVM.

Add one of the following to your `remappings.txt`, depending on how you installed the library:
```
# forge install
@taceo/babyjubjub/=lib/babyjubjub-solidity/src/

# Soldeer
@taceo/babyjubjub/=dependencies/babyjubjub-solidity-1.0.0/src/
```

## Development

```bash
forge soldeer install
forge test
```

## Security

This library has been audited part of an larger audit. Since then we extracted this as a library to better use it in other projects. 

Note: the Tate-pairing subgroup check (`isInCorrectSubgroupAssumingOnCurveTate`) was added after these audits and is not part of the audited surface. It is instead accompanied by a machine-checked Lean proof in `/proof`.

Audit reports can be found in `/audits`.
