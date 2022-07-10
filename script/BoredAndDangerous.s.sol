// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "forge-std/Script.sol";
import "../src/BoredAndDangerous.sol";

contract MyScript is Script {
    uint64 startPrice = 0.8 ether;
    uint64 endPrice = 0.2 ether;
    uint64 priceIncrement = 0.05 ether;
    uint32 startTime = uint32(block.timestamp);
    uint32 timeIncrement = 15 minutes;

    uint ownerMintId = 3962;

    function run() external {

        BoredAndDangerous book = BoredAndDangerous(0xBA627f3d081cc97ac0eDc40591eda7053AC63532);
        
        vm.startBroadcast();

        // book.setDutchAuctionStruct(BoredAndDangerous.DutchAuctionParams({
        //     startPrice: startPrice,
        //     endPrice: endPrice,
        //     priceIncrement: priceIncrement,
        //     startTime: startTime,
        //     timeIncrement: timeIncrement
        // }));

        // book.ownerMint(tx.origin, ownerMintId);

        vm.stopBroadcast();
    }
}