// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Script} from "forge-std/Script.sol";
import {BoredAndDangerous} from "../src/BoredAndDangerous.sol";
import {AzurRoot} from "../src/AzurRoot.sol";

contract AzurRootScript is Script {

    function run() external {
        vm.startBroadcast();

        // Deploy mock book
        BoredAndDangerous book = new BoredAndDangerous(1000, 1001);
        book.setBaseTokenURI("https://metadata.jenkinsthevalet.com/bnd/json/");
        book.ownerMint(address(this), 0);

        // Batch mint for goerli testing
        uint256 start = 1;
        uint256 length = 50;
        address[] memory recipients = new address[](length);
        uint256[] memory tokenIds = new uint[](length);
        for (uint i = start; i < start+length; i++) {
            recipients[i-start] = 0xe59136B4c9aeDb1EB59630CfeBffdd0B244e2086;
            tokenIds[i-start] = i;
        }
        book.ownerMintBatch(recipients, tokenIds);

        // Deploy root
        AzurRoot root = new AzurRoot(address(book));
        root.setBaseTokenURI("https://metadata.azurbala.com/azurRoot/json/");
        root.setDefaultRoyalty(address(this), 50);
        root.setBurnOpen(true);

        vm.stopBroadcast();
    }
}