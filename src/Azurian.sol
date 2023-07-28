// SPDX-License-Identifier: MIT

pragma solidity ^0.8.21;

import {MultiOwnable} from "./MultiOwnable.sol";

import {ERC721} from "solmate/tokens/ERC721.sol";
import {ERC2981} from "openzeppelin-contracts/contracts/token/common/ERC2981.sol";
import {Strings} from "openzeppelin-contracts/contracts/utils/Strings.sol";
import {DefaultOperatorFilterer} from "operator-filter-registry/DefaultOperatorFilterer.sol";

import {IAzurian} from "./AzurRoot.sol";

contract Azurian is IAzurian, DefaultOperatorFilterer, ERC721, ERC2981, MultiOwnable {
    /// @notice The azur root contract
    address public immutable ROOT;

    /// @notice Total number of tokens which have minted
    uint256 public totalSupply = 0;

    /// @notice The prefix to attach to the tokenId to get the metadata uri
    string public baseTokenURI;

    /// @notice Whether the minting is open
    bool public mintOpen;

    /// @notice Thrown when the mint is not yet open
    error MintNotOpen();

    /// @notice Thrown when an ether transfer fails
    error FailedToSendEther();

    /// @notice Thrown when metadata is queried for a nonexistent token
    error TokenDoesNotExist();

    constructor(address _root) ERC721("Azurian", "AZUR") {
        ROOT = _root;
    }

    function burnRootAndMint(uint256[] calldata rootIds) external {
        if(msg.sender != ROOT) revert AccessControl();
        if(!mintOpen) revert MintNotOpen();
        unchecked {
            for (uint256 i = 0; i < rootIds.length; ++i) {
                _mint(tx.origin, rootIds[i]);
            }
        }
        totalSupply += rootIds.length;
    }

    /////////////////////////
    // ADMIN FUNCTIONALITY //
    /////////////////////////

    /// @notice Set metadata
    function setBaseTokenURI(string memory _baseTokenURI) external {
        if (msg.sender != metadataOwner) {
            revert AccessControl();
        }
        baseTokenURI = _baseTokenURI;
    }

    /// @notice Set mint open
    function setMintOpen(bool _mintOpen) external {
        if (msg.sender != mintingOwner) {
            revert AccessControl();
        }
        mintOpen = _mintOpen;
    }

    // ROYALTY FUNCTIONALITY

    /// @dev See {IERC165-supportsInterface}.
    function supportsInterface(bytes4 interfaceId) public pure override(ERC721, ERC2981) returns (bool) {
        return interfaceId == 0x2a55205a // ERC165 Interface ID for ERC2981
            || interfaceId == 0x01ffc9a7 // ERC165 Interface ID for ERC165
            || interfaceId == 0x80ac58cd // ERC165 Interface ID for ERC721
            || interfaceId == 0x5b5e139f; // ERC165 Interface ID for ERC721Metadata
    }

    /// @dev See {ERC2981-_setDefaultRoyalty}.
    function setDefaultRoyalty(address receiver, uint96 feeNumerator) external {
        if (msg.sender != royaltyOwner) {
            revert AccessControl();
        }
        _setDefaultRoyalty(receiver, feeNumerator);
    }

    /// @dev See {ERC2981-_deleteDefaultRoyalty}.
    function deleteDefaultRoyalty() external {
        if (msg.sender != royaltyOwner) {
            revert AccessControl();
        }
        _deleteDefaultRoyalty();
    }

    /// @dev See {ERC2981-_setTokenRoyalty}.
    function setTokenRoyalty(uint256 tokenId, address receiver, uint96 feeNumerator) external {
        if (msg.sender != royaltyOwner) {
            revert AccessControl();
        }
        _setTokenRoyalty(tokenId, receiver, feeNumerator);
    }

    /// @dev See {ERC2981-_resetTokenRoyalty}.
    function resetTokenRoyalty(uint256 tokenId) external {
        if (msg.sender != royaltyOwner) {
            revert AccessControl();
        }
        _resetTokenRoyalty(tokenId);
    }

    // METADATA FUNCTIONALITY

    /// @notice Returns the metadata URI for a given token
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        if (_ownerOf[tokenId] == address(0)) revert TokenDoesNotExist();
        return string(abi.encodePacked(baseTokenURI, Strings.toString(tokenId)));
    }

    // OPERATOR FILTER

    function setApprovalForAll(address operator, bool approved) public override onlyAllowedOperatorApproval(operator) {
        super.setApprovalForAll(operator, approved);
    }

    function approve(address operator, uint256 tokenId) public override onlyAllowedOperatorApproval(operator) {
        super.approve(operator, tokenId);
    }

    function transferFrom(address from, address to, uint256 tokenId) public override onlyAllowedOperator(from) {
        super.transferFrom(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) public override onlyAllowedOperator(from) {
        super.safeTransferFrom(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes calldata data)
        public
        override
        onlyAllowedOperator(from)
    {
        super.safeTransferFrom(from, to, tokenId, data);
    }
}
