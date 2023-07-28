// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "ds-test/test.sol";
import "forge-std/console2.sol";
import "forge-std/Test.sol";

import {AzurRoot} from "src/AzurRoot.sol";
import {Azurian} from "src/Azurian.sol";
import {IDelegationRegistry} from "src/IDelegationRegistry.sol";

interface Book {
    function ownerOf(uint256 tokenId) external view returns (address);
    function transferFrom(address from, address to, uint256 id) external;
    function setApprovalForAll(address spender, bool approved) external;
    function claimFunds(address payable recipient) external;
}

contract AzurianTest is Test {
    IDelegationRegistry registry = IDelegationRegistry(0x00000000000076A84feF008CDAbe6409d2FE638B);
    Azurian azurian = new Azurian(0x0025C3ABfa72E7c509ad458b50982835404A1d6c);
    AzurRoot root = AzurRoot(azurian.ROOT());
    Book book = Book(root.BOOK());
    address user = 0xFC48426Da0338735945BaDEf273736cCFF53A358;
    address delegate = 0x28C6c06298d514Db089934071355E5743bf21d60;

    receive() external payable {}

    function setUp() public {
        vm.deal(user, 1000 ether);

        vm.label(address(this), "Tester");
        vm.label(address(book), "Book");
        vm.label(address(root), "Root");
        vm.label(address(azurian), "Azurian");
    }

    function testBurnRoots() public {
        // This requires a fork of mainnet
        if (block.timestamp <= 1000) {
            return;
        }

        vm.startPrank(user);
        uint256[] memory tokenIds = new uint[](2);
        tokenIds[0] = 6863;
        tokenIds[1] = 6739;

        // Fail before mint opens
        vm.expectRevert(abi.encodeWithSelector(Azurian.MintNotOpen.selector));
        root.burnRoots(address(azurian), tokenIds);
        vm.stopPrank();

        azurian.setMintOpen(true);

        // Prank msg.sender and tx.origin for this one
        vm.startPrank(user, user);
        root.burnRoots(address(azurian), tokenIds);
        vm.stopPrank();

        // Test that azurian minted to user
        assertEq(azurian.ownerOf(tokenIds[0]), user);

        // Test that roots are burned
        vm.expectRevert();
        root.ownerOf(tokenIds[0]);
    }

    function testBurnRootsDelegate() public {
        // This requires a fork of mainnet
        if (block.timestamp <= 1000) {
            return;
        }

        vm.startPrank(user);
        registry.delegateForAll(delegate, true);
        vm.stopPrank();

        vm.startPrank(delegate);
        uint256[] memory tokenIds = new uint[](2);
        tokenIds[0] = 6863;
        tokenIds[1] = 6739;

        // Fail before mint opens
        vm.expectRevert(abi.encodeWithSelector(Azurian.MintNotOpen.selector));
        root.burnRoots(address(azurian), tokenIds);
        vm.stopPrank();

        azurian.setMintOpen(true);

        // Fail if unrelated third party tries to call
        address hacker = 0xDB8723FdC67E515565040C2F6e43c1b8ba0d6a6b;
        vm.startPrank(hacker, hacker);
        vm.expectRevert();
        root.burnRoots(address(azurian), tokenIds);
        vm.stopPrank();

        // Prank msg.sender and tx.origin for this one
        vm.startPrank(delegate, delegate);
        root.burnRoots(address(azurian), tokenIds);
        vm.stopPrank();

        // Test that azurian minted to user
        assertEq(azurian.ownerOf(tokenIds[0]), delegate);

        // Test that roots are burned
        vm.expectRevert();
        root.ownerOf(tokenIds[0]);
    }
}
