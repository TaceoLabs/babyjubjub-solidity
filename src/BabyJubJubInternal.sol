// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import {BabyJubJub} from "./BabyJubJub.sol";
import {BabyJubJubCore as Core} from "./BabyJubJubCore.sol";

/// @title BabyJubJub Elliptic Curve Operations (internal)
/// @notice The operations of `BabyJubJub` as internal functions on memory points: inlined into the calling
/// contract, so no library deployment, linking or DELEGATECALL is needed.
/// See `BabyJubJubCore` for the preconditions of each operation.
library BabyJubJubInternal {
    uint256 internal constant Q = Core.Q;
    uint256 internal constant R = Core.R;
    uint256 internal constant A = Core.A;
    uint256 internal constant D = Core.D;

    /// @notice Returns the identity.
    function identity() internal pure returns (BabyJubJub.Affine memory p) {
        p.y = 1;
    }

    /// @notice Returns the generator.
    function generator() internal pure returns (BabyJubJub.Affine memory p) {
        p.x = Core.GEN_X;
        p.y = Core.GEN_Y;
    }

    /// @notice Adds two affine points, see `BabyJubJubCore.add`.
    function add(BabyJubJub.Affine memory lhs, BabyJubJub.Affine memory rhs)
        internal
        view
        returns (BabyJubJub.Affine memory res)
    {
        (res.x, res.y) = Core.add(lhs.x, lhs.y, rhs.x, rhs.y);
    }

    /// @notice Checks if an affine point is the identity element.
    function isIdentity(BabyJubJub.Affine memory p) internal pure returns (bool) {
        return Core.isIdentity(p.x, p.y);
    }

    /// @notice Checks whether an affine point is uninitialized, i.e., both coordinates are 0.
    function isEmpty(BabyJubJub.Affine memory p) internal pure returns (bool) {
        return p.x == 0 && p.y == 0;
    }

    /// @notice Checks whether two affine points have equal x and y coordinates.
    function isEqual(BabyJubJub.Affine memory lhs, BabyJubJub.Affine memory rhs) internal pure returns (bool) {
        return lhs.x == rhs.x && lhs.y == rhs.y;
    }

    /// @notice Checks if a point is on the curve with reduced coordinates, see `BabyJubJubCore.isOnCurve`.
    function isOnCurve(BabyJubJub.Affine memory p) internal pure returns (bool) {
        return Core.isOnCurve(p.x, p.y);
    }

    /// @notice Checks prime-order subgroup membership. The point MUST satisfy `isOnCurve(p)`,
    /// see `BabyJubJubCore.isInCorrectSubgroupAssumingOnCurveTate`.
    function isInCorrectSubgroupAssumingOnCurveTate(BabyJubJub.Affine memory p) internal view returns (bool) {
        return Core.isInCorrectSubgroupAssumingOnCurveTate(p.x, p.y);
    }

    /// @notice Validates an untrusted affine point: reduced coordinates, on the curve, and in the prime-order subgroup.
    function isValidPoint(BabyJubJub.Affine memory p) internal view returns (bool) {
        return Core.isValidPoint(p.x, p.y);
    }

    /// @notice Computes the lagrange coefficients, see `BabyJubJubCore.computeLagrangeCoefficiants`.
    function computeLagrangeCoefficiants(uint256[] memory ids, uint256 threshold, uint256 numPeers)
        internal
        view
        returns (uint256[] memory)
    {
        return Core.computeLagrangeCoefficiants(ids, threshold, numPeers);
    }

    /// @notice Computes scalar * p, see `BabyJubJubCore.scalarMul`. Reverts if scalar >= R.
    function scalarMul(uint256 scalar, BabyJubJub.Affine memory p)
        internal
        view
        returns (BabyJubJub.Affine memory res)
    {
        (res.x, res.y) = Core.scalarMul(scalar, p.x, p.y);
    }
}
