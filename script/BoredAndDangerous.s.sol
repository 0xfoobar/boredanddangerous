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

        // book.setBaseTokenURI("https://metadata.jenkinsthevalet.com/bnd/json/");

        // book.setWritelistPrice(0.15 ether);
        // book.setWritelistMintWritersRoomOpen(true);
        // book.setApeMerkleRoot(bytes32(0x446d886e541db67ff5a7065895b42d6710035de0be89be563ca8c6013eaffc45));
        // book.setGiveawayMerkleRoot(bytes32(0x922dbfe6d69bc4bb6322f95c2b6145fd2432b0589f751bee6585d2aed3f996b3));

        // book.setWritelistMintWritersRoomFreeOpen(true);
        // book.setWritelistMintWritersRoomOpen(false);
        // book.setApeMerkleRoot(bytes32(uint256(0x0)));
        // book.setGiveawayMerkleRoot(bytes32(uint256(0x0)));

        book.claimFunds(payable(0xf6045E92121A4Aac74320e038258e0Fe0D537cb5));

        vm.stopBroadcast();
    }
}