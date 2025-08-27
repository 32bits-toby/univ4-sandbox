// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test, console} from "forge-std/Test.sol";
import {IERC20} from "../src/interfaces/IERC20.sol";
import {PoolKey} from "../src/types/PoolKey.sol";
import {POOL_MANAGER, USDC} from "../src/Constants.sol";
import {TestHelper} from "./TestHelper.sol";
import {Swap} from "@exercises/Swap.sol";

contract SwapTest is Test, TestHelper {
    IERC20 constant usdc = IERC20(USDC);

    TestHelper helper;
    Swap swap;
    PoolKey poolKey;

    receive() external payable {}

    function setUp() public {
        helper = new TestHelper();

        deal(USDC, address(this), 1000 * 1e6);
        swap = new Swap(POOL_MANAGER);

        usdc.approve(address(swap), type(uint256).max);

        poolKey = PoolKey({
            currency0: address(0),
            currency1: USDC,
            fee: 500,
            tickSpacing: 10,
            hooks: address(0)
        });
    }

    function test_swapExactInputSingle_ETH_USDC() public {
        // Swap ETH to USDC
        helper.set("Before swap USDC", usdc.balanceOf(address(this)));
        helper.set("Before swap ETH", address(this).balance);

        uint128 amountIn = 1e18;
        swap.swap{value: uint256(amountIn)}(
            Swap.SwapExactInputSingleHop({
                poolKey: poolKey,
                zeroForOne: true,
                amountIn: amountIn,
                amountOutMin: 1
            })
        );

        helper.set("After swap USDC", usdc.balanceOf(address(this)));
        helper.set("After swap ETH", address(this).balance);

        int256 d0 = helper.delta("After swap ETH", "Before swap ETH");
        int256 d1 = helper.delta("After swap USDC", "Before swap USDC");

        console.log("ETH delta: %e", d0);
        console.log("USDC delta: %e", d1);

        assertLt(d0, 0, "ETH delta");
        assertGt(d1, 0, "USDC delta");
    }

    function test_swapExactInputSingle_USDC_ETH() public {
        // Swap USDC to ETH
        helper.set("Before swap USDC", usdc.balanceOf(address(this)));
        helper.set("Before swap ETH", address(this).balance);

        uint128 amountIn = 1000 * 1e6;
        swap.swap{value: uint256(amountIn)}(
            Swap.SwapExactInputSingleHop({
                poolKey: poolKey,
                zeroForOne: false,
                amountIn: amountIn,
                amountOutMin: 1
            })
        );

        helper.set("After swap USDC", usdc.balanceOf(address(this)));
        helper.set("After swap ETH", address(this).balance);

        int256 d0 = helper.delta("After swap ETH", "Before swap ETH");
        int256 d1 = helper.delta("After swap USDC", "Before swap USDC");

        console.log("ETH delta: %e", d0);
        console.log("USDC delta: %e", d1);

        assertGt(d0, 0, "ETH delta");
        assertLt(d1, 0, "USDC delta");
    }
}
