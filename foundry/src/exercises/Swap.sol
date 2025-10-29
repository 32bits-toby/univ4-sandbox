// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

// import {console} from "forge-std/Test.sol";

import {IERC20} from "../interfaces/IERC20.sol";
import {IPoolManager} from "../interfaces/IPoolManager.sol";
import {IUnlockCallback} from "../interfaces/IUnlockCallback.sol";
import {PoolKey} from "../types/PoolKey.sol";
import {SwapParams} from "../types/PoolOperation.sol";
import {BalanceDelta, BalanceDeltaLibrary} from "../types/BalanceDelta.sol";
import {SafeCast} from "../libraries/SafeCast.sol";
import {CurrencyLib} from "../libraries/CurrencyLib.sol";
import {MIN_SQRT_PRICE, MAX_SQRT_PRICE} from "../Constants.sol";

contract Swap is IUnlockCallback {
    using BalanceDeltaLibrary for BalanceDelta;
    using SafeCast for int128;
    using SafeCast for uint128;
    using CurrencyLib for address;

    IPoolManager public immutable poolManager;

    struct SwapExactInputSingleHop {
        PoolKey poolKey;
        bool zeroForOne;
        uint128 amountIn;
        uint128 amountOutMin;
    }

    modifier onlyPoolManager() {
        require(msg.sender == address(poolManager), "not pool manager");
        _;
    }

    constructor(address _poolManager) {
        poolManager = IPoolManager(_poolManager);
    }

    receive() external payable {}

    function unlockCallback(bytes calldata data)
        external
        onlyPoolManager
        returns (bytes memory)
    {
        (address receiver, SwapExactInputSingleHop memory params) =
            abi.decode(data, (address, SwapExactInputSingleHop));

        // The swapDelta represents how the pool balances changed, one increased and the other reduced, this keeps track of that in a gas optimized way.
        // This single value encodes both Δtoken0 and Δtoken1 using the format:
        // swapDelta = (int256(Δtoken0) << 128) | (uint128(Δtoken1))
        int256 swapDelta = poolManager.swap({
            key: params.poolKey,
            params: SwapParams({
                zeroForOne: params.zeroForOne,
                amountSpecified: -(params.amountIn.toInt256()),
                sqrtPriceLimitX96: params.zeroForOne
                    ? MAX_SQRT_PRICE + 1
                    : MAX_SQRT_PRICE - 1
            }),
            hookData: ""
        });

        // Here we recover both Δtoken0 and Δtoken1
        BalanceDelta delta = BalanceDelta.wrap(swapDelta);
        int128 amount0 = delta.amount0();
        int128 amount1 = delta.amount1();

        // Set values based on whether zeroForOne is true or false.
        (
            address currencyIn,
            address currencyOut,
            uint256 amountIn,
            uint256 amountOut
        ) = params.zeroForOne
            ? (
                params.poolKey.currency0,
                params.poolKey.currency1,
                (-amount0).toUint256(),
                amount1.toUint256()
            )
            : (
                params.poolKey.currency1,
                params.poolKey.currency0,
                (-amount1).toUint256(),
                amount0.toUint256()
            );

        require(amountOut >= params.amountOutMin, "amount out < min");

        poolManager.take({
            currency: currencyOut,
            to: receiver,
            amount: amountOut
        });

        // Remember you must call sync before you settle
        poolManager.sync(currencyIn);

        // Two scenarios
        // 1. When currencyIn is native token
        // 2. When currencyIn is an ERC20
        if (currencyIn == address(0)) {
            poolManager.settle{value: amountIn}();
        } else {
            IERC20(currencyIn).transfer(address(poolManager), amountIn);
            poolManager.settle();
        }

        return "";
    }

    function swap(SwapExactInputSingleHop calldata params) external payable {
        // Select input token
        address currencyIn = params.zeroForOne
            ? params.poolKey.currency0
            : params.poolKey.currency1;

        currencyIn.transferIn(msg.sender, uint256(params.amountIn));
        poolManager.unlock(abi.encode(msg.sender, params));

        // Refund
        uint256 bal = currencyIn.balanceOf(address(this));
        if (bal > 0) {
            currencyIn.transferOut(msg.sender, bal);
        }
    }
}
