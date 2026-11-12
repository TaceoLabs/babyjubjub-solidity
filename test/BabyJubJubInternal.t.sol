// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import {Test} from "forge-std/Test.sol";
import {BabyJubJub} from "../src/BabyJubJub.sol";
import {BabyJubJubInternal} from "../src/BabyJubJubInternal.sol";

/// @notice Differential tests: the internal facade must agree with the linked library.
contract BabyJubJubInternalTest is Test {
    using BabyJubJubInternal for BabyJubJub.Affine;

    uint256 constant TORSION_GENERATOR_X = 4342719913949491028786768530115087822524712248835451589697801404893164183326;
    uint256 constant TORSION_GENERATOR_Y = 4826523245007015323400664741523384119579596407052839571721035538011798951543;

    /// @dev s*G + t*T reaches every on-curve point.
    function _pointFromSeed(uint256 s, uint8 t) private view returns (BabyJubJub.Affine memory point) {
        point = BabyJubJub.scalarMul(s % BabyJubJub.R, BabyJubJub.generator());
        BabyJubJub.Affine memory torsion = BabyJubJub.Affine({x: TORSION_GENERATOR_X, y: TORSION_GENERATOR_Y});
        for (uint256 i = 0; i < t % 8; ++i) {
            point = BabyJubJub.add(point, torsion);
        }
    }

    function _assertPointEq(BabyJubJub.Affine memory a, BabyJubJub.Affine memory b) private pure {
        assertEq(a.x, b.x);
        assertEq(a.y, b.y);
    }

    function testConstants() public pure {
        assertEq(BabyJubJubInternal.Q, BabyJubJub.Q);
        assertEq(BabyJubJubInternal.R, BabyJubJub.R);
        assertEq(BabyJubJubInternal.A, BabyJubJub.A);
        assertEq(BabyJubJubInternal.D, BabyJubJub.D);
        _assertPointEq(BabyJubJubInternal.identity(), BabyJubJub.identity());
        _assertPointEq(BabyJubJubInternal.generator(), BabyJubJub.generator());
    }

    function testFuzzAddMatches(uint256 sp, uint8 tp, uint256 sq, uint8 tq) public view {
        BabyJubJub.Affine memory p = _pointFromSeed(sp, tp);
        BabyJubJub.Affine memory q = _pointFromSeed(sq, tq);
        _assertPointEq(p.add(q), BabyJubJub.add(p, q));
        _assertPointEq(p.add(BabyJubJubInternal.identity()), p);
    }

    function testFuzzScalarMulMatches(uint256 sp, uint256 scalar) public view {
        BabyJubJub.Affine memory p = _pointFromSeed(sp, 0);
        scalar %= BabyJubJub.R;
        _assertPointEq(BabyJubJubInternal.scalarMul(scalar, p), BabyJubJub.scalarMul(scalar, p));
    }

    function testScalarMulRevertsOnOutOfRangeScalar() public {
        BabyJubJub.Affine memory g = BabyJubJubInternal.generator();
        vm.expectRevert();
        this.scalarMulExternal(BabyJubJub.R, g);
    }

    function scalarMulExternal(uint256 scalar, BabyJubJub.Affine memory p)
        external
        view
        returns (BabyJubJub.Affine memory)
    {
        return BabyJubJubInternal.scalarMul(scalar, p);
    }

    function testFuzzChecksMatchOnCurve(uint256 s, uint8 t) public view {
        BabyJubJub.Affine memory p = _pointFromSeed(s, t);
        assertTrue(p.isOnCurve());
        assertEq(p.isInCorrectSubgroupAssumingOnCurveTate(), t % 8 == 0);
        assertEq(p.isValidPoint(), t % 8 == 0);
    }

    function testFuzzChecksMatchArbitrary(uint256 x, uint256 y, uint256 x2, uint256 y2) public view {
        BabyJubJub.Affine memory p = BabyJubJub.Affine({x: x, y: y});
        BabyJubJub.Affine memory q = BabyJubJub.Affine({x: x2, y: y2});
        assertEq(p.isOnCurve(), BabyJubJub.isOnCurve(p));
        assertEq(p.isValidPoint(), BabyJubJub.isValidPoint(p));
        assertEq(p.isIdentity(), BabyJubJub.isIdentity(p));
        assertEq(p.isEmpty(), BabyJubJub.isEmpty(p));
        assertEq(p.isEqual(q), BabyJubJub.isEqual(p, q));
        assertTrue(p.isEqual(p));
    }

    function testSpecialPoints() public pure {
        assertTrue(BabyJubJubInternal.identity().isIdentity());
        assertTrue(BabyJubJub.Affine({x: 0, y: 0}).isEmpty());
        assertFalse(BabyJubJub.Affine({x: 0, y: 0}).isOnCurve());
    }

    function testLagrangeMatches() public view {
        uint256[] memory ids = new uint256[](3);
        ids[0] = 4;
        ids[1] = 0;
        ids[2] = 2;
        uint256[] memory a = BabyJubJubInternal.computeLagrangeCoefficiants(ids, 3, 5);
        uint256[] memory b = BabyJubJub.computeLagrangeCoefficiants(ids, 3, 5);
        assertEq(a, b);
    }
}
