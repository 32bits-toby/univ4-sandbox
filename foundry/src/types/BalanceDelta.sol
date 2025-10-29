// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/// @dev Two `int128` values packed into a single `int256` where the upper 128 bits represent the amount0
/// and the lower 128 bits represent the amount1.
type BalanceDelta is int256;

/// @notice Library for getting the amount0 and amount1 deltas from the BalanceDelta type
library BalanceDeltaLibrary {
    /// @notice A BalanceDelta of 0
    BalanceDelta public constant ZERO_DELTA = BalanceDelta.wrap(0);

    function amount0(BalanceDelta balanceDelta)
        internal
        pure
        returns (int128 _amount0)
    {
        assembly ("memory-safe") {
            // arithmetic shift right by 128 bits.
            _amount0 := sar(128, balanceDelta)
        }
    }

    function amount1(BalanceDelta balanceDelta)
        internal
        pure
        returns (int128 _amount1)
    {
        assembly ("memory-safe") {
            // Interpret the lower 16 bytes (128 bits = 16 bytes) as a signed integer, and extend its sign bit to fill 256 bits.
            _amount1 := signextend(15, balanceDelta)
        }
    }
}
