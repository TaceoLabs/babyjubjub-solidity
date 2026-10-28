# Changelog

All notable changes to this project will be documented in this file.

## [1.4.0] - 2026-10-28

### 🚜 Refactor

- Use non-modular additions to save gas where no overflows can occur ([d0ae694](https://github.com/TaceoLabs/babyjubjub-solidity/commit/d0ae69429051af872bef1984eae81d6a15c2bf70))

### 📚 Documentation

- Add report for subgroup checks and follow-up optimizations ([a50208c](https://github.com/TaceoLabs/babyjubjub-solidity/commit/a50208c08069dc8e9a51db5076ee01c3682a2d34))

## [1.3.0] - 2026-10-07

### 🚜 Refactor

- Rename assembly locals that shadowed curve constants ([b32c2a6](https://github.com/TaceoLabs/babyjubjub-solidity/commit/b32c2a6fef1263ec89a790c50436ff04c18c4cf6))

### ⚡ Performance

- Use the modexp precompile for field inversions (#13) ([783862d](https://github.com/TaceoLabs/babyjubjub-solidity/commit/783862db9fd02fb83717fdcf5669ec4f70b8ef77))
- Rewrite scalar multiplication core in assembly ([048ad67](https://github.com/TaceoLabs/babyjubjub-solidity/commit/048ad6791064374b763c31ba7cfae2d482d5186c))
- Hoist the loop-invariant d*X2*Y2 out of the mixed addition ([bbcfd4c](https://github.com/TaceoLabs/babyjubjub-solidity/commit/bbcfd4ce48959168fdcbe87c8e48b7bacaa13d60))
- Seed the scalar multiplication accumulator with the base point ([ee35a67](https://github.com/TaceoLabs/babyjubjub-solidity/commit/ee35a676507bfebe87267172488667a476ec0b41))

## [1.2.0] - 2026-09-28

### 🚜 Refactor

- Restructure the multiplications for `ND^7` to share squarings with the previous steps. (#10) ([01ada24](https://github.com/TaceoLabs/babyjubjub-solidity/commit/01ada24596306363885b5c3059484a7c17e2b68f))

## [1.1.0] - 2026-09-01

### ⛰️ Features

- Implement a much more gas-efficient prime order subgroup membership check based on the Tate Pairing (#7) ([e7cbf22](https://github.com/TaceoLabs/babyjubjub-solidity/commit/e7cbf220d676c1b00d73608d10c2bb3ed2f3287d))

### 🏗️ Build

- Move from submodules to soldeer ([458649e](https://github.com/TaceoLabs/babyjubjub-solidity/commit/458649e06d941cb519d47e417bd8a7611b9ac746))

### 📚 Documentation

- Add a basic lean proof showing no uint256 overflows occur (#6) ([02a4a52](https://github.com/TaceoLabs/babyjubjub-solidity/commit/02a4a5238ba259380009b806f638c59ce3af99f7))

### 🧪 Testing

- Added fuzzing tests (#8) ([51a2350](https://github.com/TaceoLabs/babyjubjub-solidity/commit/51a2350182eef3c73497ae3e38f56a56f9bcf4ed))

## [1.0.0] - 2026-02-27

### ⛰️ Features

- Init commit ([f9fedbd](https://github.com/TaceoLabs/babyjubjub-solidity/commit/f9fedbd49cfc01ae0a39a072c69c11ac0dfe8daa))
- Added babyjubjub impl from other repo ([49a3e99](https://github.com/TaceoLabs/babyjubjub-solidity/commit/49a3e993c518ff2cc62f2b05c14bb31e9e14dbd3))

### 📚 Documentation

- Added readme ([c0223fc](https://github.com/TaceoLabs/babyjubjub-solidity/commit/c0223fc1ac6b419b3d91bb664bfa7b719fa969d2))

