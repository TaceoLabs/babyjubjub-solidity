// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

/// @title BabyJubJub Elliptic Curve Operations
/// @notice A library for performing operations on the BabyJubJub elliptic curve. At the moment limited to point addition and curve membership check.
library BabyJubJub {
    // BN254 scalar field = BabyJubJub base field
    uint256 public constant Q = 21888242871839275222246405745257275088548364400416034343698204186575808495617;

    // BabyJubJub scalar field
    uint256 public constant R = 2736030358979909402780800718157159386076813972158567259200215660948447373041;

    // BabyJubJub curve parameters
    uint256 public constant A = 168700;
    uint256 public constant D = 168696;

    uint256 constant GEN_X = 5299619240641551281634865583518297030282874472190772894086521144482721001553;
    uint256 constant GEN_Y = 16950150798460657717958625567821834550301663161624707787222815936182638968203;

    // Constants for the reduced 8-Tate pairing subgroup check. Baby JubJub is
    // birational to the Montgomery curve v^2 = u^3 + 168698*u^2 + u. The
    // point T = [R]G below has order eight on that curve, where G is the
    // ERC-2494 full-order generator of order 8*R (not the order-R base point
    // GEN_X/GEN_Y above). TATE_TANGENT_0 is the tangent slope at T; the
    // tangent slope at [2]T equals TATE_TWO_T_Y.
    // TATE_FINAL_EXPONENT is the final exponent (Q - 1) / 8 of the reduced
    // 8-Tate pairing.
    uint256 private constant TATE_FINAL_EXPONENT =
        2736030358979909402780800718157159386068545550052004292962275523321976061952;
    uint256 private constant TATE_T_X = 19799329160503878365519859265345525785148473002902384773314932802961476726446;
    uint256 private constant TATE_T_Y = 17254532040196108728490891380973133526547459744854918265191993098218014369797;
    uint256 private constant TATE_TANGENT_0 =
        5125366436769623165205660392107939355810725029703343239946747673935168202680;
    // [2]T has Montgomery coordinates (1, TATE_TWO_T_Y), and its tangent
    // slope happens to equal its y-coordinate.
    uint256 private constant TATE_TWO_T_Y =
        14673962723734255200314198873237586429337747973199041533368185129026308523766;

    error ModExpPrecompileFailed();

    struct Affine {
        uint256 x;
        uint256 y;
    }

    /// @notice Returns the identity.
    function identity() public pure returns (Affine memory p) {
        p.x = 0;
        p.y = 1;
    }

    /// @notice Returns the generator.
    function generator() public pure returns (Affine memory p) {
        p.x = GEN_X;
        p.y = GEN_Y;
    }

    /// @notice Adds two affine points.
    /// This method expects that the point is on the curve and in the correct subgroup. Additionally, the method expects that the coordinates are reduced mod Q. The outputs are also reduced mod Q.
    ///
    /// @param lhs The point on the left hand side.
    /// @param rhs The point on the right hand side.
    /// @return res The resulting point
    function add(Affine calldata lhs, Affine calldata rhs) public view returns (Affine memory res) {
        // Handle identity cases
        if (isIdentity(lhs)) {
            res = rhs;
            return res;
        }
        if (isIdentity(rhs)) {
            res = lhs;
            return res;
        }
        uint256 x1 = lhs.x;
        uint256 y1 = lhs.y;
        uint256 x2 = rhs.x;
        uint256 y2 = rhs.y;

        uint256 x1x2 = mulmod(x1, x2, Q);
        uint256 y1y2 = mulmod(y1, y2, Q);
        uint256 dx1x2y1y2 = mulmod(D, mulmod(x1x2, y1y2, Q), Q);

        // x3 = (x1*y2 + y1*x2) / (1 + d*x1*x2*y1*y2)
        // SAFETY: can add without mod because Q is 254 bits
        uint256 x3Num = mulmod(x1, y2, Q) + mulmod(y1, x2, Q);
        // SAFETY: can add without mod because Q is 254 bits
        uint256 x3Den = 1 + dx1x2y1y2;

        // y3 = (y1*y2 - a*x1*x2) / (1 - d*x1*x2*y1*y2)
        uint256 y3Num = _submod(y1y2, mulmod(A, x1x2, Q), Q);
        uint256 y3Den = _submod(1, dx1x2y1y2, Q);

        // Batch the two inversions: inv(x3Den * y3Den) yields both inverses with one modexp call.
        // Both denominators are nonzero for on-curve inputs since the curve is complete.
        uint256 invDen = _modInverse(mulmod(x3Den, y3Den, Q), Q);
        res.x = mulmod(x3Num, mulmod(invDen, y3Den, Q), Q);
        res.y = mulmod(y3Num, mulmod(invDen, x3Den, Q), Q);
    }

    /// @notice Checks if an affine point is the identity element.
    ///
    /// @param p The point.
    /// @return True iff the point is the identity element, false otherwise.
    function isIdentity(Affine calldata p) public pure returns (bool) {
        return p.x == 0 && p.y == 1;
    }

    /// @notice Checks whether an affine point is initialized.
    ///
    /// @param p The point.
    /// @return True iff the x and y coordinates are 0.
    function isEmpty(Affine calldata p) public pure returns (bool) {
        return p.x == 0 && p.y == 0;
    }

    /// @notice Checks whether two affine points are equal, by checking their x and y coordinates for equality.
    ///
    /// @param lhs The left hand side.
    /// @param rhs The right hand side.
    /// @return True iff both points have equal x and y coordinates.
    function isEqual(Affine calldata lhs, Affine calldata rhs) public pure returns (bool) {
        return lhs.x == rhs.x && lhs.y == rhs.y;
    }

    /// @notice Checks if a point in affine form is on curve: a*x^2 + y^2 = 1 + d*x^2*y^2 and its coordinates are in the basefield (smaller than Q).
    ///
    /// @param p The affine point.
    /// @return True if the point is on the BabyJubJub curve, false otherwise.
    function isOnCurve(Affine calldata p) public pure returns (bool) {
        if (isIdentity(p)) return true;
        if (p.x >= Q || p.y >= Q) return false;

        uint256 xx = mulmod(p.x, p.x, Q);
        uint256 yy = mulmod(p.y, p.y, Q);
        uint256 axx = mulmod(A, xx, Q);
        uint256 dxxyy = mulmod(D, mulmod(xx, yy, Q), Q);

        return addmod(axx, yy, Q) == addmod(1, dxxyy, Q);
    }

    /// @notice Checks if a point in affine form is in the sub-group with the same order as the scalarfield.
    /// @dev The point MUST be on the curve with both coordinates reduced mod Q (i.e., `isOnCurve(p)`
    ///      must hold); the result is meaningless otherwise. Callers must verify this precondition
    ///      before relying on the result.
    /// @param p The affine point. Must satisfy `isOnCurve(p)`.
    /// @return True if the point is in the correct sub-subgroup, false otherwise.
    function isInCorrectSubgroupAssumingOnCurve(Affine calldata p) public pure returns (bool) {
        (uint256 x1, uint256 y1, uint256 z1) = _scalarMulInner(R, p.x, p.y);
        return x1 == 0 && y1 == z1 && p.y != 0;
    }

    /// @notice Checks prime-order subgroup membership using a reduced 8-Tate pairing.
    /// @dev The point MUST be on the curve with both coordinates reduced mod Q (i.e., `isOnCurve(p)`
    ///      must hold); this precondition is safety-critical. Unlike
    ///      `isInCorrectSubgroupAssumingOnCurve`, this check can accept points that are not on the
    ///      curve, and it may revert (instead of returning false) for unreduced coordinates. Callers
    ///      must verify the precondition before relying on the result.
    ///      The check uses the fact that Baby JubJub is cyclic of order 8*R and 8 divides Q-1. If T is
    ///      a point of order eight, the prime-order subgroup is exactly the kernel of P -> t_8(T, P).
    ///      The final field exponentiation is evaluated by the EVM modular-exponentiation precompile.
    ///      Reference: Koshelev, "Subgroup membership testing on elliptic curves via the Tate
    ///      pairing", J. Cryptographic Engineering 13 (2023), https://eprint.iacr.org/2022/037
    ///      (its published Correction, JCEN 14 (2024), only concerns the extension-field case
    ///      e ∤ q-1, which does not apply here since 8 | Q-1).
    /// @param p The affine point. Must satisfy `isOnCurve(p)`.
    /// @return True if the point is in the prime-order subgroup, false otherwise.
    function isInCorrectSubgroupAssumingOnCurveTate(Affine calldata p) public view returns (bool) {
        // The Edwards identity has no image under the affine Edwards-to-Montgomery map.
        if (isIdentity(p)) return true;
        return _modExpPrecompile(_tateMillerValue(p.x, p.y), TATE_FINAL_EXPONENT, Q) == 1;
    }

    /// @notice Validates an untrusted affine point: reduced coordinates, on the curve, and in the
    ///         prime-order subgroup. Combines `isOnCurve` with the Tate-based subgroup check, whose
    ///         result is meaningless on its own for points not known to be on the curve.
    /// @param p The affine point.
    /// @return True if the point is on the curve and in the prime-order subgroup, false otherwise.
    function isValidPoint(Affine calldata p) public view returns (bool) {
        return isOnCurve(p) && isInCorrectSubgroupAssumingOnCurveTate(p);
    }

    /// @notice Computes the lagrange coefficients for the provided party IDs (starting at zero) and the threshold of the secret-sharing. We expect callsite to check that. Importantly, this method will always return an array with length numPeers, where lagrange coefficient of party ID is on index in the array (with zero for not participating nodes). We need this because the nodes will access this array with their partyID.
    /// This method will revert if either of those cases occurs:
    ///    * the length of ids != numPeers
    ///    * the ids are not distinct
    ///    * the ids are not unique
    ///
    ///  All of those checks must be enforced at callsite. It is considered a bug if this method revert for either of that reasons, therefore we also don't revert with a meaningful error.
    /// @param ids The party IDs (coefficients of the polynomial) of the participating parties (starting with ID 0)
    /// @param threshold The degree of the polynomial + 1
    /// @return lagrange The requested lagrange coefficients
    function computeLagrangeCoefficiants(uint256[] calldata ids, uint256 threshold, uint256 numPeers)
        public
        view
        returns (uint256[] memory lagrange)
    {
        // should be checked at callsite
        require(ids.length == threshold);
        // check that all ids are distinct and smaller than numPeers
        for (uint256 i = 0; i < threshold; ++i) {
            require(ids[i] < numPeers);
            for (uint256 j = i + 1; j < threshold; ++j) {
                require(ids[i] != ids[j]);
            }
        }
        lagrange = new uint256[](numPeers);
        for (uint256 i = 0; i < threshold; ++i) {
            uint256 num = 1;
            uint256 den = 1;
            uint256 currentId = ids[i] + 1;
            for (uint256 j = 0; j < threshold; ++j) {
                uint256 otherId = ids[j] + 1;
                if (currentId != otherId) {
                    num = mulmod(num, otherId, R);
                    den = mulmod(den, _submod(otherId, currentId, R), R);
                }
            }
            lagrange[ids[i]] = mulmod(num, _modInverse(den, R), R);
        }
        return lagrange;
    }

    /// @notice Computes xP, where x is an element of the scalarfield of BabyJubJub and P is an affine point on the BabyJubJub curve. This method reverts if scalar doesn't fit into BabyJubJub's scalarfield.
    ///
    /// This method expects that the point is on the curve and in the correct subgroup. Additionally, the method expects that the coordinates are reduced mod Q. The outputs are also reduced mod Q.
    ///
    /// @param scalar The scalar for the multiplication.
    /// @param p The affine point.
    /// @return The resulting affine point.
    function scalarMul(uint256 scalar, Affine calldata p) public view returns (Affine memory) {
        require(scalar < R);
        if (scalar == 0) {
            return identity();
        }
        (uint256 x1, uint256 y1, uint256 z1) = _scalarMulInner(scalar, p.x, p.y);
        return _toAffine(x1, y1, z1);
    }

    /// @notice Internal helper for scalar point multiplication. Left-to-right double-and-add over the
    /// bits of `scalar` in extended twisted Edwards coordinates, starting at the highest set bit.
    /// Written in assembly to keep the ~250 iterations on the stack (no memory bit array, no tuple returns).
    ///
    /// This method expects that the point is on the curve and in the correct subgroup. Additionally, the method expects that the coordinates are reduced mod Q. The outputs are also reduced mod Q.
    ///
    /// @param scalar The scalar. Must be nonzero (callers handle zero).
    /// @param x The x-coordinate of the affine point reduced mod Q
    /// @param y The y-coordinate of the affine point reduced mod Q
    ///
    /// @return x_res The projective x-coordinate of the result.
    /// @return y_res The projective y-coordinate of the result.
    /// @return z_res The projective z-coordinate of the result.
    function _scalarMulInner(uint256 scalar, uint256 x, uint256 y)
        private
        pure
        returns (uint256 x_res, uint256 y_res, uint256 z_res)
    {
        assembly ("memory-safe") {
            // The helpers below reuse their return slots as temporaries and read the fixed base
            // point from scratch memory, so that the legacy code generator stays within stack limits.
            // Additions without mod are safe: all operands are reduced mod Q (254 bits), so sums fit
            // in 255 bits; a - b is computed as a + (Q - b) mod Q.

            // Doubling, "Twisted Edwards Curves Revisited" (Hisil, Wong, Carter, Dawson), 3.3 Doubling in E^e
            // https://www.hyperelliptic.org/EFD/g1p/data/twisted/extended/doubling/dbl-2008-hwcd
            // Paper names in comments; `A` and `D` in code are the curve constants.
            function dbl(x1, y1, z1) -> x3, y3, t3, z3 {
                let xx := mulmod(x1, x1, Q)
                let yy := mulmod(y1, y1, Q)
                // E = (X1+Y1)^2 - A - B
                x3 := add(x1, y1)
                x3 := addmod(mulmod(x3, x3, Q), sub(Q, addmod(xx, yy, Q)), Q)
                // D = a*A
                xx := mulmod(xx, A, Q)
                // G = D + B
                y3 := add(xx, yy)
                // F = G - C, C = 2*Z1^2
                z3 := addmod(y3, sub(Q, mulmod(mul(2, z1), z1, Q)), Q)
                // H = D - B
                xx := addmod(xx, sub(Q, yy), Q)
                t3 := mulmod(x3, xx, Q)
                yy := mulmod(y3, xx, Q)
                x3 := mulmod(x3, z3, Q)
                z3 := mulmod(z3, y3, Q)
                y3 := yy
            }

            // Mixed addition with the affine point (mload(0x00), mload(0x20)), ibid. 3.1 Unified Addition in E^e
            // https://www.hyperelliptic.org/EFD/g1p/data/twisted/extended/addition/madd-2008-hwcd
            function madd(x1, y1, t1, z1) -> x3, y3, t3, z3 {
                let xx := mulmod(x1, mload(0x00), Q)
                let yy := mulmod(y1, mload(0x20), Q)
                // C = T1*d*X2*Y2
                x3 := mulmod(mulmod(mulmod(D, t1, Q), mload(0x00), Q), mload(0x20), Q)
                // E = (X1+Y1)*(X2+Y2) - A - B
                t3 := addmod(mulmod(add(x1, y1), add(mload(0x00), mload(0x20)), Q), sub(Q, addmod(xx, yy, Q)), Q)
                // F = Z1 - C
                y3 := addmod(z1, sub(Q, x3), Q)
                // G = Z1 + C
                z3 := add(z1, x3)
                // H = B - a*A
                xx := addmod(yy, sub(Q, mulmod(A, xx, Q)), Q)
                x3 := mulmod(t3, y3, Q)
                yy := mulmod(z3, xx, Q)
                t3 := mulmod(t3, xx, Q)
                z3 := mulmod(y3, z3, Q)
                y3 := yy
            }

            mstore(0x00, x)
            mstore(0x20, y)
            // accumulator (X:Y:T:Z) = identity
            x_res := 0
            y_res := 1
            let t := 0
            z_res := 1
            let i := 255
            for {} iszero(and(shr(i, scalar), 1)) {} { i := sub(i, 1) }
            for {} 1 {} {
                x_res, y_res, t, z_res := dbl(x_res, y_res, z_res)
                if and(shr(i, scalar), 1) { x_res, y_res, t, z_res := madd(x_res, y_res, t, z_res) }
                if iszero(i) { break }
                i := sub(i, 1)
            }
        }
    }

    /// @notice Converts a point P on the BabyJubJub curve in projective form to its affine form.
    /// This method will not check whether the points are on the curve nor if they are in the correct subgroup.
    ///
    /// @param x1 The x-coordinate of the projective point.
    /// @param y1 The y-coordinate of the projective point.
    /// @param z1 The z-coordinate of the projective point.
    ///
    /// @return res The affine point
    function _toAffine(uint256 x1, uint256 y1, uint256 z1) private view returns (Affine memory res) {
        // The projective point X, Y, Z is represented in the affine coordinates as X/Z, Y/Z.
        if (x1 == 0 && y1 == z1 && y1 != 1) {
            res.x = 0;
            res.y = 1;
        } else if (z1 == 1) {
            // If Z is one, the point is already normalized.
            res.x = x1;
            res.y = y1;
        } else {
            // Z is nonzero, so it must have an inverse in a field.
            uint256 z_inv = _modInverse(z1, Q);
            res.x = mulmod(x1, z_inv, Q);
            res.y = mulmod(y1, z_inv, Q);
        }
    }

    function _submod(uint256 a, uint256 b, uint256 m) private pure returns (uint256) {
        return (a >= b) ? (a - b) : m - (b - a);
    }

    /// @dev Computes a^(P-2) mod P via the modexp precompile. Returns 0 for a == 0.
    function _modInverse(uint256 a, uint256 P) private view returns (uint256) {
        return _modExpPrecompile(a, P - 2, P);
    }

    /// @dev Evaluates the Miller function f_{8,T}(P) of the reduced 8-Tate
    /// pairing, which in this setting reduces to
    ///   N/D = line(T)^4 * line([2]T)^2 / (W * (U-W)^4 * U).
    /// Returns N * D^7 = (N/D) * D^8, which agrees with N/D after the final
    /// exponentiation by (Q-1)/8 since D^(Q-1) = 1. The product is computed
    /// as ((line0 * D)^2 * line1 * D)^2 * D to share the squarings.
    function _tateMillerValue(uint256 x, uint256 y) private pure returns (uint256) {
        // Projective Montgomery coordinates for
        //   u = (1+y)/(1-y), v = (1+y)/((1-y)*x):
        //   (U : V : W) = ((1+y)*x : 1+y : (1-y)*x).
        // Keeping the coordinates projective avoids a field inversion.
        uint256 v = addmod(1, y, Q);
        uint256 u = mulmod(v, x, Q);
        uint256 w = mulmod(_submod(1, y, Q), x, Q);

        // Numerators of the tangent-line evaluations at T and [2]T, folded
        // using TATE_TANGENT_0 * TATE_T_X - TATE_T_Y == TATE_T_X (mod Q):
        //   line0 = v - TATE_T_Y*w - TATE_TANGENT_0*(u - TATE_T_X*w)
        //         = v - TATE_TANGENT_0*u + TATE_T_X*w
        //   line1 = v - TATE_TWO_T_Y*w - TATE_TWO_T_Y*(u - w)
        //         = v - TATE_TWO_T_Y*u
        uint256 line0 = addmod(_submod(v, mulmod(TATE_TANGENT_0, u, Q), Q), mulmod(TATE_T_X, w, Q), Q);
        uint256 line1 = _submod(v, mulmod(TATE_TWO_T_Y, u, Q), Q);
        uint256 denominator = _tateMillerDenominator(u, w);

        // (N/D)^((Q-1)/8) = (N*D^7)^((Q-1)/8), since D^(Q-1) = 1.
        // Under the on-curve assumption the Miller value can vanish (via a zero
        // numerator or a zero denominator) only at nonidentity torsion points;
        // returning zero correctly rejects those, matching the early-abort
        // convention of Dai et al., https://eprint.iacr.org/2024/1790, Alg. 5.
        uint256 line0Denominator = mulmod(line0, denominator, Q);
        uint256 inner = mulmod(mulmod(mulmod(line0Denominator, line0Denominator, Q), line1, Q), denominator, Q);
        return mulmod(mulmod(inner, inner, Q), denominator, Q);
    }

    function _tateMillerDenominator(uint256 u, uint256 w) internal pure returns (uint256) {
        // D = W * (U-W)^4 * U
        uint256 uMinusW = _submod(u, w, Q);
        uint256 uMinusWSquared = mulmod(uMinusW, uMinusW, Q);
        return mulmod(mulmod(w, mulmod(uMinusWSquared, uMinusWSquared, Q), Q), u, Q);
    }

    /// @dev Evaluates base^exponent mod modulus using the EVM precompile at address 0x05.
    function _modExpPrecompile(uint256 base, uint256 exponent, uint256 modulus) private view returns (uint256 result) {
        bool success;
        assembly ("memory-safe") {
            // The input region past the free memory pointer is only used
            // transiently within this block, so the pointer is not advanced;
            // the result lands in the 0x00 scratch space.
            let input := mload(0x40)
            mstore(input, 0x20)
            mstore(add(input, 0x20), 0x20)
            mstore(add(input, 0x40), 0x20)
            mstore(add(input, 0x60), base)
            mstore(add(input, 0x80), exponent)
            mstore(add(input, 0xa0), modulus)

            success := staticcall(gas(), 0x05, input, 0xc0, 0x00, 0x20)
            success := and(success, eq(returndatasize(), 0x20))
            result := mload(0x00)
        }
        if (!success) revert ModExpPrecompileFailed();
    }
}
