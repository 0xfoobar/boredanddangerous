// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "forge-std/Script.sol";
import "../src/BoredAndDangerous.sol";

contract MyScript is Script {
    uint64 startPrice = 0.8 ether;
    uint64 endPrice = 0.2 ether;
    uint64 priceIncrement = 0.05 ether;
    uint32 startTime = 1657548000;
    uint32 timeIncrement = 15 minutes;

    // uint ownerMintId = 3962;
    uint ownerMintId = 3963;

    function run() external {

        BoredAndDangerous book = BoredAndDangerous(0x766A68Ee875419C76EA6436ddc9C827068BEc206);
        
        vm.startBroadcast();

        book.setDutchAuctionStruct(BoredAndDangerous.DutchAuctionParams({
            startPrice: startPrice,
            endPrice: endPrice,
            priceIncrement: priceIncrement,
            startTime: startTime,
            timeIncrement: timeIncrement
        }));

        book.ownerMint(tx.origin, ownerMintId);

        book.setBaseTokenURI("https://metadata.jenkinsthevalet.com/bnd/json/");

        vm.stopBroadcast();
    }
}