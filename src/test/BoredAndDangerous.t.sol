// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "ds-test/test.sol";
import "forge-std/console2.sol";
import "forge-std/Test.sol";

import {Merkle} from "murky/Merkle.sol";

import {BoredAndDangerous} from "../BoredAndDangerous.sol";
import {BoredAndDangerousBatchHelper} from "../BoredAndDangerousBatchHelper.sol";

interface IERC721 {
    function ownerOf(uint tokenId) external view returns (address);
}

contract BoredAndDangerousTest is Merkle, Test {
    uint public constant AMOUNT = 1;
    uint public constant DUTCH_AUCTION_START_ID = 6943;
    uint public constant DUTCH_AUCTION_END_ID = 9309;

    BoredAndDangerous book;
    BoredAndDangerousBatchHelper helper;
    address user = 0x000000000000000000000000000000000000dEaD;
    uint64 startPrice = 0.8 ether;
    uint64 endPrice = 0.2 ether;
    uint64 priceIncrement = 0.05 ether;
    uint32 startTime = uint32(block.timestamp);
    uint32 timeIncrement = 15 minutes;

    address newAddress = 0x1000000000000000000000000000000000000000;

    receive() external payable {}

    function setUp() public {
        vm.deal(user, 1000 ether);
        book = new BoredAndDangerous(DUTCH_AUCTION_START_ID, DUTCH_AUCTION_END_ID);
        helper = new BoredAndDangerousBatchHelper(address(book));
        book.setDutchAuctionStruct(BoredAndDangerous.DutchAuctionParams({
            startPrice: startPrice,
            endPrice: endPrice,
            priceIncrement: priceIncrement,
            startTime: startTime,
            timeIncrement: timeIncrement
        }));

        vm.label(address(this), "Tester");
        vm.label(address(book), "Book");
        vm.label(address(helper), "Helper");
    }

    function generateNewAddress() public {
        newAddress = address(uint160(newAddress) + 1);
    }

    function testOwnerMint() public {
        uint tokenId = 3;
        book.ownerMint(address(this), tokenId);
        assertEq(book.ownerOf(tokenId), address(this));
    }

    function testDutchAuctionMint() public {
        // Set tx.origin as well
        vm.startPrank(user, user);
        book.dutchAuctionMint{value: AMOUNT * startPrice}(AMOUNT);

        for (uint i = 0; i < AMOUNT; ++i) {
            assertEq(book.ownerOf(6943+i), user);
        }
    }

    function testDutchAuctionRefund() public {
        // Mint one for ourselves
        vm.startPrank(user, user);
        book.dutchAuctionMint{value: startPrice}(1);
        vm.stopPrank();

        // Then mint out of the dutch auction over 
        uint totalToMint = DUTCH_AUCTION_END_ID - DUTCH_AUCTION_START_ID + 1;
        for (uint i = 0; i < totalToMint - 1; ++i) {
            generateNewAddress();
            vm.deal(newAddress, 1000 ether);
            vm.startPrank(newAddress, newAddress);
            uint price = book.dutchAuctionPrice();
            book.dutchAuctionMint{value: price}(1);
            vm.stopPrank();
            vm.warp(block.timestamp + 2); // 3k seconds, or ~1 hours total
        }

        assertGt(startPrice, book.dutchAuctionPrice());
        assertLt(endPrice, book.dutchAuctionPrice());

        vm.startPrank(user);
        uint startBalance = user.balance;
        address[] memory users = new address[](1);
        users[0] = user;
        book.claimDutchAuctionRefund(users);
        uint endBalance = user.balance;

        (uint128 actualEndPrice,) = book.dutchEnd();
        assertEq(endBalance - startBalance, startPrice - actualEndPrice, "wrong refund");

        // Claiming a second time should be a no-op
        book.claimDutchAuctionRefund(users);
        uint doubleEndBalance = user.balance;
        assertEq(doubleEndBalance, endBalance, "user got a second refund");
        vm.stopPrank();

        // Fail to withdraw funds until auction period has ended
        (uint128 dutchEndPrice, uint128 dutchEndTime) = book.dutchEnd();
        vm.expectRevert(abi.encodeWithSelector(BoredAndDangerous.DutchAuctionGracePeriod.selector, dutchEndPrice, dutchEndTime));
        book.claimFunds(payable(address(this)));

        // Let the time period pass
        vm.warp(block.timestamp + book.DUTCH_AUCTION_GRACE_PERIOD());

        // Successfully claim funds
        uint prevBalance = address(this).balance;
        book.claimFunds(payable(address(this)));
        assertGt(address(this).balance, prevBalance, "Did not send ether");
    }

    function testWritelistMintWritersRoom() public {
        // This requires a fork of mainnet
        if (block.timestamp <= 1000) {
            return;
        }

        uint tokenId = 1;

        uint[] memory tokenIds = new uint[](1);
        tokenIds[0] = tokenId;
        // Should revert before mint is opened
        vm.expectRevert(BoredAndDangerous.MintNotOpen.selector);
        book.writelistMintWritersRoomFree(tokenIds);

        book.setWritelistMintWritersRoomFreeOpen(true);
        book.writelistMintWritersRoomFree(tokenIds);
    }

    function testWritelistApes() public {
        // This requires a fork of mainnet
        if (block.timestamp <= 1000) {
            return;
        }

        address bayc = 0xBC4CA0EdA7647A8aB7C2061c2E118A18a936f13D;
        address mayc = 0x60E4d786628Fea6478F785A6d7e704777c86a7c6;
        uint numAccounts = 100;

        Merkle m = new Merkle();
        // Generate Data
        bytes32[] memory data = new bytes32[](numAccounts);
        data[0] = keccak256(abi.encodePacked(bayc, uint256(19)));
        data[1] = keccak256(abi.encodePacked(bayc, uint256(33)));
        data[2] = keccak256(abi.encodePacked(mayc, uint256(20)));
        data[3] = keccak256(abi.encodePacked(mayc, uint256(25)));
        bytes32 root = m.getRoot(data);

        book.setApeMerkleRoot(root);
        book.setWritelistPrice(1 ether);

        book.writelistMintApes{value: book.writelistPrice()}(bayc, 19, data[0], m.getProof(data, 0));
    }

    function testWritelistMintGiveawayMass() public {
        uint numAccounts = 100;

        // Initialize
        Merkle m = new Merkle();
        // Generate Data
        bytes32[] memory data = new bytes32[](numAccounts);
        for (uint i = 0; i < numAccounts; ++i) {
            vm.deal(newAddress, 1000 ether);
            data[i] = keccak256(abi.encodePacked(newAddress, uint8(1)));
            generateNewAddress();
        }
        // Get Root, Proof, and Verify
        bytes32 root = m.getRoot(data);

        book.setGiveawayMerkleRoot(root);
        book.setWritelistPrice(1 ether);
        newAddress = 0x1000000000000000000000000000000000000000;
        for (uint i = 0; i < numAccounts; ++i) {
            vm.startPrank(newAddress);
            bytes32[] memory proof = m.getProof(data, i);
            book.writelistMintGiveaway{value: book.writelistPrice()}(newAddress, 1, 1, data[i], proof);
            vm.stopPrank();
            generateNewAddress();
        }
    }

    function testWritelistMintGiveawayBatch() public {
        uint numAccounts = 100;
        uint numAccountsToBatch = 100;

        // Initialize
        Merkle m = new Merkle();
        // Generate Data
        bytes32[] memory data = new bytes32[](numAccounts);
        for (uint i = 0; i < numAccounts; ++i) {
            vm.deal(newAddress, 1000 ether);
            data[i] = keccak256(abi.encodePacked(newAddress, uint8(1)));
            generateNewAddress();
        }
        // Get Root, Proof, and Verify
        bytes32 root = m.getRoot(data);

        book.setGiveawayMerkleRoot(root);
        book.setWritelistPrice(1 ether);
        newAddress = 0x1000000000000000000000000000000000000000;

        bytes[] memory calls = new bytes[](numAccountsToBatch);
        uint[] memory msgValues = new uint[](numAccountsToBatch);

        uint totalMsgValue = 0;
        for (uint i = 0; i < numAccountsToBatch; ++i) {
            bytes32[] memory proof = m.getProof(data, i);
            calls[i] = abi.encodeWithSignature(
                "writelistMintGiveaway(address,uint8,uint8,bytes32,bytes32[])",
                newAddress, 1, 1, data[i], proof
            );
            msgValues[i] = book.writelistPrice();
            totalMsgValue += msgValues[i];
            generateNewAddress();
        }
        helper.batch{value: totalMsgValue}(calls, msgValues, true);
    }

    function testEverything() public {
        // This requires a fork of mainnet
        if (block.timestamp <= 1000) {
            return;
        }    

        // First the dutch auction will happen
        // Simulate selling out at a price somewhere in the middle
        vm.warp(startTime);

        // Then mint out of the dutch auction over 
        uint totalToMint = DUTCH_AUCTION_END_ID - DUTCH_AUCTION_START_ID + 1;
        for (uint i = 0; i < totalToMint; ++i) {
            generateNewAddress();
            vm.deal(newAddress, 1000 ether);
            vm.startPrank(newAddress, newAddress);
            uint price = book.dutchAuctionPrice();
            book.dutchAuctionMint{value: price}(1);
            vm.stopPrank();
            vm.warp(block.timestamp + 2); // 3k seconds, or ~1 hours total
        }

        // Issue refunds

        // Claim team funds
        vm.warp(block.timestamp + book.DUTCH_AUCTION_GRACE_PERIOD());
        // book.claimFunds(payable(address(this)));

        // Open writelist mint an hour or so after dutch auction concludes
        book.setWritelistMintWritersRoomOpen(true);
        book.setApeMerkleRoot(bytes32(uint256(0x1)));
        book.setGiveawayMerkleRoot(bytes32(uint256(0x1)));

        // Close paid writelist mints two days later and open free claims
        vm.warp(block.timestamp + 2 days);
        book.setWritelistMintWritersRoomOpen(false);
        book.setApeMerkleRoot(bytes32(uint256(0x0)));
        book.setGiveawayMerkleRoot(bytes32(uint256(0x0)));

        book.setWritelistMintWritersRoomFreeOpen(true);

        // Close free claims a week later, owner mint one, claim funds, burn mintingOwner
        vm.warp(block.timestamp + 7 days);
        book.setWritelistMintWritersRoomFreeOpen(false);
        book.ownerMint(address(this), 7);
        book.claimFunds(payable(address(this)));
        book.setMintingOwner(address(0x0));
    }
}
