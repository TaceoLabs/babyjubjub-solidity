// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import {Test} from "forge-std/Test.sol";
import {BabyJubJub} from "../src/BabyJubJub.sol";

/// @title Property-based fuzz tests for the BabyJubJub library.
/// @notice Complements the known-answer tests in BabyJubJub.t.sol with
/// algebraic properties (group law, scalar multiplication homomorphisms,
/// membership checks, Lagrange reconstruction) checked over fuzzed inputs.
contract BabyJubJubFuzzTest is Test {
    uint256 constant TORSION_GENERATOR_X = 4342719913949491028786768530115087822524712248835451589697801404893164183326;
    uint256 constant TORSION_GENERATOR_Y = 4826523245007015323400664741523384119579596407052839571721035538011798951543;

    // ---------------------------------------------------------------------
    // helpers
    // ---------------------------------------------------------------------

    function _negate(BabyJubJub.Affine memory p) private pure returns (BabyJubJub.Affine memory) {
        if (p.x == 0) return p;
        return BabyJubJub.Affine({x: BabyJubJub.Q - p.x, y: p.y});
    }

    function _torsionGenerator() private pure returns (BabyJubJub.Affine memory) {
        return BabyJubJub.Affine({x: TORSION_GENERATOR_X, y: TORSION_GENERATOR_Y});
    }

    /// @dev The curve group is cyclic of order 8*R, so s*G + t*T (t in 0..7)
    /// reaches every on-curve point.
    function _pointFromSeed(uint256 s, uint8 t) private pure returns (BabyJubJub.Affine memory point) {
        s %= BabyJubJub.R;
        t %= 8;
        point = BabyJubJub.scalarMul(s, BabyJubJub.generator());
        BabyJubJub.Affine memory torsionGenerator = _torsionGenerator();
        for (uint256 i = 0; i < t; ++i) {
            point = BabyJubJub.add(point, torsionGenerator);
        }
    }

    function _subgroupPointFromSeed(uint256 s) private pure returns (BabyJubJub.Affine memory) {
        return BabyJubJub.scalarMul(s % BabyJubJub.R, BabyJubJub.generator());
    }

    function _assertPointEq(BabyJubJub.Affine memory a, BabyJubJub.Affine memory b) private pure {
        assertEq(a.x, b.x);
        assertEq(a.y, b.y);
    }

    // ---------------------------------------------------------------------
    // A. group law
    // ---------------------------------------------------------------------

    function testFuzzAddCommutative(uint256 sp, uint256 sq) public pure {
        BabyJubJub.Affine memory p = _subgroupPointFromSeed(sp);
        BabyJubJub.Affine memory q = _subgroupPointFromSeed(sq);
        _assertPointEq(BabyJubJub.add(p, q), BabyJubJub.add(q, p));
    }

    function testFuzzAddAssociative(uint256 sp, uint256 sq, uint256 ss) public pure {
        BabyJubJub.Affine memory p = _subgroupPointFromSeed(sp);
        BabyJubJub.Affine memory q = _subgroupPointFromSeed(sq);
        BabyJubJub.Affine memory s = _subgroupPointFromSeed(ss);
        _assertPointEq(BabyJubJub.add(BabyJubJub.add(p, q), s), BabyJubJub.add(p, BabyJubJub.add(q, s)));
    }

    function testFuzzAddIdentityIsNoop(uint256 sp) public pure {
        BabyJubJub.Affine memory p = _subgroupPointFromSeed(sp);
        BabyJubJub.Affine memory identity = BabyJubJub.identity();
        _assertPointEq(BabyJubJub.add(p, identity), p);
        _assertPointEq(BabyJubJub.add(identity, p), p);
    }

    function testFuzzAddInverse(uint256 sp) public pure {
        BabyJubJub.Affine memory p = _subgroupPointFromSeed(sp);
        BabyJubJub.Affine memory sum = BabyJubJub.add(p, _negate(p));
        _assertPointEq(sum, BabyJubJub.identity());
    }

    function testFuzzAddClosedOverSubgroup(uint256 sp, uint256 sq) public pure {
        BabyJubJub.Affine memory p = _subgroupPointFromSeed(sp);
        BabyJubJub.Affine memory q = _subgroupPointFromSeed(sq);
        BabyJubJub.Affine memory sum = BabyJubJub.add(p, q);
        assertTrue(BabyJubJub.isOnCurve(sum));
        assertTrue(BabyJubJub.isInCorrectSubgroupAssumingOnCurve(sum));
    }

    function testFuzzAddSelfMatchesScalarMulTwo(uint256 sp) public pure {
        BabyJubJub.Affine memory p = _subgroupPointFromSeed(sp);
        _assertPointEq(BabyJubJub.add(p, p), BabyJubJub.scalarMul(2, p));
    }

    // ---------------------------------------------------------------------
    // B. scalar multiplication
    // ---------------------------------------------------------------------

    function testFuzzScalarMulZeroIsIdentity(uint256 sp) public pure {
        BabyJubJub.Affine memory p = _subgroupPointFromSeed(sp);
        _assertPointEq(BabyJubJub.scalarMul(0, p), BabyJubJub.identity());
    }

    function testFuzzScalarMulOneIsNoop(uint256 sp) public pure {
        BabyJubJub.Affine memory p = _subgroupPointFromSeed(sp);
        _assertPointEq(BabyJubJub.scalarMul(1, p), p);
    }

    function testFuzzScalarMulMaxScalarIsNegation(uint256 sp) public pure {
        BabyJubJub.Affine memory p = _subgroupPointFromSeed(sp);
        _assertPointEq(BabyJubJub.scalarMul(BabyJubJub.R - 1, p), _negate(p));
    }

    function testFuzzScalarMulAdditiveHomomorphism(uint256 sp, uint256 a, uint256 b) public pure {
        BabyJubJub.Affine memory p = _subgroupPointFromSeed(sp);
        a %= BabyJubJub.R;
        b %= BabyJubJub.R;
        BabyJubJub.Affine memory lhs = BabyJubJub.scalarMul(addmod(a, b, BabyJubJub.R), p);
        BabyJubJub.Affine memory rhs = BabyJubJub.add(BabyJubJub.scalarMul(a, p), BabyJubJub.scalarMul(b, p));
        _assertPointEq(lhs, rhs);
    }

    function testFuzzScalarMulMultiplicativeHomomorphism(uint256 sp, uint256 a, uint256 b) public pure {
        BabyJubJub.Affine memory p = _subgroupPointFromSeed(sp);
        a %= BabyJubJub.R;
        b %= BabyJubJub.R;
        BabyJubJub.Affine memory lhs = BabyJubJub.scalarMul(mulmod(a, b, BabyJubJub.R), p);
        BabyJubJub.Affine memory rhs = BabyJubJub.scalarMul(a, BabyJubJub.scalarMul(b, p));
        _assertPointEq(lhs, rhs);
    }

    function testFuzzScalarMulClosedOverSubgroup(uint256 sp, uint256 scalar) public pure {
        BabyJubJub.Affine memory p = _subgroupPointFromSeed(sp);
        BabyJubJub.Affine memory result = BabyJubJub.scalarMul(scalar % BabyJubJub.R, p);
        assertTrue(BabyJubJub.isOnCurve(result));
        assertTrue(BabyJubJub.isInCorrectSubgroupAssumingOnCurve(result));
    }

    function testFuzzScalarMulRevertsOnOutOfRangeScalar(uint256 sp, uint256 scalar) public {
        BabyJubJub.Affine memory p = _subgroupPointFromSeed(sp);
        scalar = bound(scalar, BabyJubJub.R, type(uint256).max);
        vm.expectRevert();
        this.scalarMulExternal(scalar, p);
    }

    function scalarMulExternal(uint256 scalar, BabyJubJub.Affine calldata p)
        external
        pure
        returns (BabyJubJub.Affine memory)
    {
        return BabyJubJub.scalarMul(scalar, p);
    }

    // ---------------------------------------------------------------------
    // C. validation / membership
    // ---------------------------------------------------------------------

    function testFuzzIsValidPointNeverRevertsAndMatchesComponents(uint256 x, uint256 y) public view {
        BabyJubJub.Affine memory p = BabyJubJub.Affine({x: x, y: y});
        bool valid = BabyJubJub.isValidPoint(p);
        bool onCurve = BabyJubJub.isOnCurve(p);
        bool expected = onCurve && BabyJubJub.isInCorrectSubgroupAssumingOnCurveTate(p);
        assertEq(valid, expected);
    }

    function testFuzzIsValidPointMatchesSubgroupMembership(uint256 s, uint8 t) public view {
        BabyJubJub.Affine memory p = _pointFromSeed(s, t);
        assertEq(BabyJubJub.isValidPoint(p), t % 8 == 0);
    }

    function testFuzzIsOnCurveRejectsUnreducedCoordinates(uint256 x, uint256 y, bool bumpX, bool bumpY) public pure {
        x %= BabyJubJub.Q;
        y %= BabyJubJub.Q;
        vm.assume(bumpX || bumpY);
        if (bumpX) x += BabyJubJub.Q;
        if (bumpY) y += BabyJubJub.Q;
        BabyJubJub.Affine memory p = BabyJubJub.Affine({x: x, y: y});
        assertFalse(BabyJubJub.isOnCurve(p));
    }

    function testFuzzIsOnCurveMatchesCurveEquation(uint256 x, uint256 y) public pure {
        x %= BabyJubJub.Q;
        y %= BabyJubJub.Q;
        BabyJubJub.Affine memory p = BabyJubJub.Affine({x: x, y: y});
        uint256 Q = BabyJubJub.Q;
        uint256 xx = mulmod(x, x, Q);
        uint256 yy = mulmod(y, y, Q);
        uint256 lhs = addmod(mulmod(BabyJubJub.A, xx, Q), yy, Q);
        uint256 rhs = addmod(1, mulmod(BabyJubJub.D, mulmod(xx, yy, Q), Q), Q);
        assertEq(BabyJubJub.isOnCurve(p), lhs == rhs);
    }

    function testFuzzIsIdentityMatchesIsEqualToIdentity(uint256 x, uint256 y) public pure {
        BabyJubJub.Affine memory p = BabyJubJub.Affine({x: x, y: y});
        assertEq(BabyJubJub.isIdentity(p), BabyJubJub.isEqual(p, BabyJubJub.identity()));
    }

    function testFuzzIsEqualReflexive(uint256 x, uint256 y) public pure {
        BabyJubJub.Affine memory p = BabyJubJub.Affine({x: x, y: y});
        assertTrue(BabyJubJub.isEqual(p, p));
    }

    function testFuzzIsEmptyMatchesZeroCoordinates(uint256 x, uint256 y) public pure {
        BabyJubJub.Affine memory p = BabyJubJub.Affine({x: x, y: y});
        assertEq(BabyJubJub.isEmpty(p), x == 0 && y == 0);
    }

    // ---------------------------------------------------------------------
    // D. Lagrange coefficients
    // ---------------------------------------------------------------------

    /// @dev Deterministically shuffles [0, numPeers) with a fuzzed seed and
    /// takes the first `threshold` entries as participating ids, so distinct
    /// ids hold by construction.
    function _shuffledIds(uint256 seed, uint256 numPeers) private pure returns (uint256[] memory ids) {
        ids = new uint256[](numPeers);
        for (uint256 i = 0; i < numPeers; ++i) {
            ids[i] = i;
        }
        for (uint256 i = numPeers; i > 1; --i) {
            seed = uint256(keccak256(abi.encode(seed, i)));
            uint256 j = seed % i;
            (ids[i - 1], ids[j]) = (ids[j], ids[i - 1]);
        }
    }

    function testFuzzLagrangeReconstructsPolynomialAtZero(
        uint256 seed,
        uint256 numPeersSeed,
        uint256 thresholdSeed,
        uint256 coeffSeed
    ) public pure {
        uint256 R = BabyJubJub.R;
        uint256 numPeers = bound(numPeersSeed, 2, 10);
        uint256 threshold = bound(thresholdSeed, 1, numPeers);

        uint256[] memory shuffled = _shuffledIds(seed, numPeers);
        uint256[] memory ids = new uint256[](threshold);
        for (uint256 i = 0; i < threshold; ++i) {
            ids[i] = shuffled[i];
        }

        // Random polynomial f of degree threshold-1 over F_R.
        uint256[] memory coeffs = new uint256[](threshold);
        for (uint256 i = 0; i < threshold; ++i) {
            coeffs[i] = uint256(keccak256(abi.encode(coeffSeed, i))) % R;
        }

        uint256[] memory lagrange = BabyJubJub.computeLagrangeCoefficiants(ids, threshold, numPeers);
        assertEq(lagrange.length, numPeers);

        uint256 reconstructed = 0;
        for (uint256 i = 0; i < threshold; ++i) {
            uint256 evalAtId = _evalPoly(coeffs, ids[i] + 1, R);
            reconstructed = addmod(reconstructed, mulmod(lagrange[ids[i]], evalAtId, R), R);
        }
        assertEq(reconstructed, _evalPoly(coeffs, 0, R));
    }

    function _evalPoly(uint256[] memory coeffs, uint256 x, uint256 m) private pure returns (uint256 result) {
        uint256 xPow = 1;
        for (uint256 i = 0; i < coeffs.length; ++i) {
            result = addmod(result, mulmod(coeffs[i], xPow, m), m);
            xPow = mulmod(xPow, x, m);
        }
    }

    function testFuzzLagrangeNonParticipantsAreZero(uint256 seed, uint256 numPeersSeed, uint256 thresholdSeed)
        public
        pure
    {
        uint256 numPeers = bound(numPeersSeed, 2, 10);
        uint256 threshold = bound(thresholdSeed, 1, numPeers);

        uint256[] memory shuffled = _shuffledIds(seed, numPeers);
        uint256[] memory ids = new uint256[](threshold);
        bool[] memory participating = new bool[](numPeers);
        for (uint256 i = 0; i < threshold; ++i) {
            ids[i] = shuffled[i];
            participating[ids[i]] = true;
        }

        uint256[] memory lagrange = BabyJubJub.computeLagrangeCoefficiants(ids, threshold, numPeers);
        for (uint256 i = 0; i < numPeers; ++i) {
            if (!participating[i]) assertEq(lagrange[i], 0);
        }
    }

    function testFuzzLagrangeRevertsOnLengthMismatch(uint256 threshold, uint256 idsLength) public {
        threshold = bound(threshold, 1, 10);
        idsLength = bound(idsLength, 0, 10);
        vm.assume(idsLength != threshold);
        uint256[] memory ids = new uint256[](idsLength);
        vm.expectRevert();
        BabyJubJub.computeLagrangeCoefficiants(ids, threshold, 10);
    }

    function testFuzzLagrangeRevertsOnDuplicateIds(uint256 seed, uint256 numPeersSeed) public {
        uint256 numPeers = bound(numPeersSeed, 2, 10);
        uint256 threshold = 2;
        uint256[] memory shuffled = _shuffledIds(seed, numPeers);
        uint256[] memory ids = new uint256[](2);
        ids[0] = shuffled[0];
        ids[1] = shuffled[0];
        vm.expectRevert();
        BabyJubJub.computeLagrangeCoefficiants(ids, threshold, numPeers);
    }

    function testFuzzLagrangeRevertsOnIdOutOfRange(uint256 seed, uint256 numPeersSeed) public {
        uint256 numPeers = bound(numPeersSeed, 1, 10);
        uint256[] memory ids = new uint256[](1);
        ids[0] = numPeers + (seed % 1000);
        vm.expectRevert();
        BabyJubJub.computeLagrangeCoefficiants(ids, 1, numPeers);
    }
}
