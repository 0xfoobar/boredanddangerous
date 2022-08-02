// SPDX-License-Identifier: MIT

pragma solidity ^0.8.15;

import {MultiOwnable} from "./MultiOwnable.sol";

import {ERC721} from "solmate/tokens/ERC721.sol";
import {ERC2981} from "openzeppelin-contracts/contracts/token/common/ERC2981.sol";
import {Strings} from "openzeppelin-contracts/contracts/utils/Strings.sol";


interface IERC721 {
    function ownerOf(uint tokenId) external view returns (address);
    function transferFrom(address from, address to, uint id) external;
}


contract AzurRoot is ERC721, ERC2981, MultiOwnable {
    /// @notice The bored and dangerous contract
    address public constant BOOK = 0xBA627f3d081cc97ac0eDc40591eda7053AC63532;
    /// @notice The price for burning a book into an azur root
    uint public constant BURN_PRICE = 0.08 ether;

    /// @notice Total number of tokens which have minted
    uint public totalSupply = 0;

    /// @notice The prefix to attach to the tokenId to get the metadata uri
    string public baseTokenURI;

    /// @notice Whether the burning is open
    bool public burnOpen;

    /// @notice The time an azur root token id was minted
    mapping(uint => uint) mintTimes;

    /// @notice Emitted when a token is minted
    event Mint(address indexed owner, uint indexed tokenId);

    /// @notice Raised when the mint has not reached the required timestamp
    error MintNotOpen();
    /// @notice Raised when two calldata arrays do not have the same length
    error MismatchedArrays();
    /// @notice Raised when `sender` does not pass the proper ether amount to `recipient`
    error FailedToSendEther(address sender, address recipient);

    constructor() ERC721("Azur Root", "ROOT") {}

    function rootAge(uint id) external view returns (uint) {
        return block.timestamp - mintTimes[id];
    }

    function _mint(address to, uint id) internal override {
        super._mint(to, id);
        mintTimes[id] = block.timestamp;
    }

    /// @notice Admin mint a batch of tokens
    function ownerMint(address[] calldata recipients) external {
        if (msg.sender != mintingOwner) {
            revert AccessControl();
        }

        unchecked {
            uint _totalSupply = totalSupply;
            for (uint i = 0; i < recipients.length; ++i) {
                _mint(recipients[i], _totalSupply+i);
            }
            totalSupply += recipients.length;
        }
    }

    //////////////////
    // BOOK BURNING //
    //////////////////

    /// @notice Burn a book to receive an azur root
    function burnBooks(uint[] calldata tokenIds) external payable {
        if (!burnOpen) {
            revert MintNotOpen();
        }
        // Check payment
        if (msg.value != tokenIds.length * BURN_PRICE) {
            revert FailedToSendEther(msg.sender, address(this));
        }

        // Cache the totalSupply to minimize storage reads
        uint _totalSupply = totalSupply;
        for (uint i = 0; i < tokenIds.length; ++i) {
            // Attempt to transfer token from the msg sender, revert if not owned or approved
            IERC721(BOOK).transferFrom(msg.sender, address(this), tokenIds[i]);
            _mint(msg.sender, _totalSupply + i);
        }
        totalSupply += tokenIds.length;
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

    /// @notice Set burn open
    function setBurnOpen(bool _burnOpen) external {
        if (msg.sender != mintingOwner) {
            revert AccessControl();
        }
        burnOpen = _burnOpen;
    }

    /// @notice Claim funds
    function claimFunds(address payable recipient) external {
        if (!(msg.sender == mintingOwner || msg.sender == metadataOwner || msg.sender == royaltyOwner)) {
            revert AccessControl();
        }

        (bool sent,) = recipient.call{value: address(this).balance}("");
        if (!sent) {
            revert FailedToSendEther(address(this), recipient);
        }
    }

    // ROYALTY FUNCTIONALITY

    /// @dev See {IERC165-supportsInterface}.
    function supportsInterface(bytes4 interfaceId) public pure override(ERC721, ERC2981) returns (bool) {
        return
            interfaceId == 0x2a55205a || // ERC165 Interface ID for ERC2981
            interfaceId == 0x01ffc9a7 || // ERC165 Interface ID for ERC165
            interfaceId == 0x80ac58cd || // ERC165 Interface ID for ERC721
            interfaceId == 0x5b5e139f; // ERC165 Interface ID for ERC721Metadata
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
        return string(abi.encodePacked(baseTokenURI, Strings.toString(tokenId)));
    }
}

