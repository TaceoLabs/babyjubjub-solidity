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
forge soldeer install babyjubjub-solidity~1.1.0
```

Or add it to your `foundry.toml`:
```toml
[dependencies]
babyjubjub-solidity = "1.1.0"
```

## Usage

```solidity
import "babyjubjub-solidity/BabyJubJub.sol";

using BabyJubJub for BabyJubJub.Affine;
```

For an untrusted affine point, use the combined check:

```solidity
require(BabyJubJub.isValidPoint(point));
```

which checks the canonical coordinates and curve equation (`isOnCurve`) before the gas-efficient
subgroup check (`isInCorrectSubgroupAssumingOnCurveTate`). The subgroup check's result is meaningless
on its own for points not known to be on the curve, so never skip the `isOnCurve` part.

The Tate-based check implements the method of [Koshelev, "Subgroup membership testing on elliptic curves via the Tate pairing", J. Cryptographic Engineering 13 (2023)](https://eprint.iacr.org/2022/037).
It is `view` because it uses the EVM modular-exponentiation precompile at address `0x05`.
On chains without this precompile it reverts with `ModExpPrecompileFailed` on every non-identity call
(the identity point is accepted before reaching the precompile). The original pure
`isInCorrectSubgroupAssumingOnCurve` order-multiplication check remains available as a portable fallback that
works on any EVM.

Add one of the following to your `remappings.txt`, depending on how you installed the library:
```
# forge install
@taceo/babyjubjub/=lib/babyjubjub-solidity/src/

# Soldeer
@taceo/babyjubjub/=dependencies/babyjubjub-solidity-1.1.0/src/
```

## Development

```bash
forge soldeer install
forge test
```

## Security

This library has been audited part of an larger audit. Since then we extracted this as a library to better use it in other projects. 

Note: the Tate-pairing subgroup check (`isInCorrectSubgroupAssumingOnCurveTate`) was added after these audits and is not part of the audited surface. It is instead accompanied by a Lean proof in `docs/lean`: the Solidity arithmetic transcription, all fixed constants, torsion rejection, and the group theory are machine-checked, while standard Tate-pairing facts (bilinearity, non-degeneracy) enter as explicitly stated model assumptions — see `docs/lean/README.md` for the exact trust boundary.

Audit reports can be found in `/audits`.
