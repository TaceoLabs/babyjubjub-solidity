// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import {BabyJubJubCore as Core} from "./BabyJubJubCore.sol";

/// @title BabyJubJub Elliptic Curve Operations
/// @notice A library for performing operations on the BabyJubJub elliptic curve, to be deployed and linked.
/// Use `BabyJubJubInternal` for the same operations inlined into the calling contract.
/// See `BabyJubJubCore` for the preconditions of each operation.
library BabyJubJub {
    // BN254 scalar field = BabyJubJub base field
    uint256 public constant Q = Core.Q;
    // BabyJubJub scalar field
    uint256 public constant R = Core.R;

    // BabyJubJub curve parameters
    uint256 public constant A = Core.A;
    uint256 public constant D = Core.D;

    uint256 constant GEN_X = Core.GEN_X;
    uint256 constant GEN_Y = Core.GEN_Y;

    struct Affine {
        uint256 x;
        uint256 y;
    }

    /// @notice Returns the identity.
    function identity() public pure returns (Affine memory p) {
        p.y = 1;
    }

    /// @notice Returns the generator.
    function generator() public pure returns (Affine memory p) {
        p.x = GEN_X;
        p.y = GEN_Y;
    }

    /// @notice Adds two affine points, see `BabyJubJubCore.add`.
    function add(Affine calldata lhs, Affine calldata rhs) public view returns (Affine memory res) {
        (res.x, res.y) = Core.add(lhs.x, lhs.y, rhs.x, rhs.y);
    }

    /// @notice Checks if an affine point is the identity element.
    function isIdentity(Affine calldata p) public pure returns (bool) {
        return Core.isIdentity(p.x, p.y);
    }

    /// @notice Checks whether an affine point is uninitialized, i.e., both coordinates are 0.
    function isEmpty(Affine calldata p) public pure returns (bool) {
        return p.x == 0 && p.y == 0;
    }

    /// @notice Checks whether two affine points have equal x and y coordinates.
    function isEqual(Affine calldata lhs, Affine calldata rhs) public pure returns (bool) {
        return lhs.x == rhs.x && lhs.y == rhs.y;
    }

    /// @notice Checks if a point is on the curve with reduced coordinates, see `BabyJubJubCore.isOnCurve`.
    function isOnCurve(Affine calldata p) public pure returns (bool) {
        return Core.isOnCurve(p.x, p.y);
    }

    /// @notice Checks prime-order subgroup membership. The point MUST satisfy `isOnCurve(p)`,
    /// see `BabyJubJubCore.isInCorrectSubgroupAssumingOnCurveTate`.
    function isInCorrectSubgroupAssumingOnCurveTate(Affine calldata p) public view returns (bool) {
        return Core.isInCorrectSubgroupAssumingOnCurveTate(p.x, p.y);
    }

    /// @notice Validates an untrusted affine point: reduced coordinates, on the curve, and in the prime-order subgroup.
    function isValidPoint(Affine calldata p) public view returns (bool) {
        return Core.isValidPoint(p.x, p.y);
    }

    /// @notice Computes the lagrange coefficients, see `BabyJubJubCore.computeLagrangeCoefficiants`.
    function computeLagrangeCoefficiants(uint256[] calldata ids, uint256 threshold, uint256 numPeers)
        public
        view
        returns (uint256[] memory)
    {
        return Core.computeLagrangeCoefficiants(ids, threshold, numPeers);
    }

    /// @notice Computes scalar * p, see `BabyJubJubCore.scalarMul`. Reverts if scalar >= R.
    function scalarMul(uint256 scalar, Affine calldata p) public view returns (Affine memory res) {
        (res.x, res.y) = Core.scalarMul(scalar, p.x, p.y);
    }
}
