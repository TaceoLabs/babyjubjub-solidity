# Lean proof

`BabyJubJubProof.lean` is a dependency-free Lean 4 refinement proof of the
arithmetic in `src/BabyJubJub.sol`. It proves:

- the affine formula is the standard twisted-Edwards addition formula;
- mixed extended-projective addition and doubling refine their modular-field
  specifications;
- double-and-add scalar multiplication refines those operations by induction;
- every ordinary addition and `2*z` in the Solidity implementation is below
  `2^256`, assuming the documented invariant that coordinates are below `Q`.

Run it with:

```sh
lake build
```

The proof is a refinement proof of the implementation under its documented
preconditions. It deliberately does not claim that arbitrary, unreduced
`uint256` inputs are safe or that call sites satisfy those preconditions.

`specAdd`, `specMixedAdd`, and `specDouble` transcribe the standard complete
twisted-Edwards affine law and the cited Hisil--Wong--Carter--Dawson extended
coordinate laws. Thus the checked result is implementation refinement to those
curve laws; this small dependency-free development does not rebuild the
general algebraic proof of those published formulas from field axioms.
