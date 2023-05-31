// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "ds-test/test.sol";
import "forge-std/console2.sol";
import "forge-std/Test.sol";

import {AzurRoot} from "../AzurRoot.sol";

interface Book {
    function ownerOf(uint tokenId) external view returns (address);
    function transferFrom(address from, address to, uint id) external;
    function setApprovalForAll(address spender, bool approved) external;
    function claimFunds(address payable recipient) external;
}

contract AzurRootTest is Test {
    AzurRoot root = new AzurRoot(0xBA627f3d081cc97ac0eDc40591eda7053AC63532);
    Book book = Book(root.BOOK());
    address user = 0xFC48426Da0338735945BaDEf273736cCFF53A358;

    receive() external payable {}

    function setUp() public {
        vm.deal(user, 1000 ether);

        vm.label(address(this), "Tester");
        vm.label(address(book), "Book");
        vm.label(address(root), "Root");
    }

    function testOwnerMint() public {
        address[] memory recipients = new address[](1);
        recipients[0] = address(this);
        root.ownerMint(recipients);
        assertEq(root.ownerOf(0), address(this));
    }

    function testBurn() public {
        // This requires a fork of mainnet
        if (block.timestamp <= 1000) {
            return;
        } 

        vm.startPrank(user);
        uint[] memory tokenIds = new uint[](2);
        tokenIds[0] = 48;
        tokenIds[1] = 50;

        // Set approval for root to spend your book
        book.setApprovalForAll(address(root), true);

        // Fail before mint opens
        vm.expectRevert(abi.encodeWithSelector(AzurRoot.MintNotOpen.selector));
        root.burnBooks(tokenIds);
        vm.stopPrank();

        // Open burn, then burn successfully
        root.setBurnOpen(true);

        vm.startPrank(user);
        root.burnBooks(tokenIds);
        vm.stopPrank();
        
        vm.warp(block.timestamp + 1 days);

        // Burn the azur root, like users will do for avatars
        vm.expectRevert('NOT_AUTHORIZED');
        root.burn(0);
        vm.startPrank(user);
        root.setApprovalForAll(address(this), true);
        vm.stopPrank();
        root.burn(0);
    }

    function testClaimFunds() public {
        // Deal funds into the contract
        uint value = 1 ether;
        vm.deal(address(root), value);

        // Then claim them
        uint prevBalance = address(this).balance;
        root.claimFunds(payable(address(this)));
        assertEq(address(this).balance - prevBalance, value);
    }
}
