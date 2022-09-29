// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "ds-test/test.sol";
import "forge-std/console2.sol";
import "forge-std/Test.sol";

import {RefundableDutchAuction} from "../RefundableDutchAuction.sol";

interface IERC721 {
    function ownerOf(uint tokenId) external view returns (address);
}

contract RefundableDutchAuctionTest is Test {
    RefundableDutchAuction dutch;

    uint public constant DUTCH_AUCTION_START_ID = 0;
    uint public constant DUTCH_AUCTION_END_ID = 9999;

    function setUp() public {
        dutch = new RefundableDutchAuction(DUTCH_AUCTION_START_ID, DUTCH_AUCTION_END_ID);
    }
}