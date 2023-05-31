// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {ERC721} from "solmate/tokens/ERC721.sol";
import {Strings} from "openzeppelin-contracts/contracts/utils/Strings.sol";

contract RefundableDutchAuction is ERC721 {
    /// @notice Raised when an unauthorized user calls a gated function
    error AccessControl();
    /// @notice Raised when the user attempts to mint after the dutch auction finishes
    error DutchAuctionOver();
    /// @notice Raised when the admin attempts to withdraw funds before the dutch auction grace period has ended
    error DutchAuctionGracePeriod();
    /// @notice Raised when a user attempts to claim their dutch auction refund before the dutch auction ends
    error DutchAuctionNotOver();
    /// @notice Raised when the admin attempts to mint within the dutch auction range while the auction is still ongoing
    error DutchAuctionNotOverAdmin();
    /// @notice Raised when the admin attempts to set dutch auction parameters that don't make sense
    error DutchAuctionBadParamsAdmin();
    /// @notice Raised when a user exceeds their mint cap
    error ExceededUserMintCap();
    /// @notice Raised when `sender` does not pass the proper ether amount to `recipient`
    error FailedToSendEther(address sender, address recipient);
    /// @notice Raised when the mint has not reached the required timestamp
    error MintNotOpen();
    /// @notice Raised when the user attempts to mint zero items
    error MintZero();

    /// @notice Records the price and time when the final dutch auction token sells out
    struct DutchAuctionFinalization {
        uint128 price;
        uint128 time;
    }

    /// @notice Struct is packed to fit within a single 256-bit slot
    struct DutchAuctionMintHistory {
        uint128 amount;
        uint128 price;
    }

    /// @notice Struct is packed to fit within a single 256-bit slot
    /// @dev uint64 has max value 1.8e19, or 18 ether
    /// @dev uint32 has max value 4.2e9, which corresponds to max timestamp of year 2106
    struct DutchAuctionParams {
        uint64 startPrice;
        uint64 endPrice;
        uint64 priceIncrement;
        uint32 startTime;
        uint32 timeIncrement;
    }

    /// @notice The grace period for refund claiming
    uint public constant DUTCH_AUCTION_GRACE_PERIOD = 24 hours;
    /// @notice The mint cap in the dutch auction
    uint public constant DUTCH_AUCTION_MINT_CAP = 5;
    /// @notice The first token id that dutch auction minters will receive, inclusive
    uint public immutable DUTCH_AUCTION_START_ID;
    /// @notice The last token id that dutch auction minters will receive, inclusive
    uint public immutable DUTCH_AUCTION_END_ID;

    /// @notice The address which can admin mint for free, set merkle roots, and set auction params
    address public mintingOwner;
    /// @notice The address which can update the metadata uri
    address public metadataOwner;
    /// @notice The address which will be returned for the ERC721 owner() standard for setting royalties
    address public royaltyOwner;

    /// @notice Total number of tokens which have minted
    uint public totalSupply = 0;
    /// @notice The prefix to attach to the tokenId to get the metadata uri
    string public baseTokenURI;

    /// @notice The instantiation of dutch auction parameters
    DutchAuctionParams public params;
    /// @notice The instantiation of the dutch auction finalization struct
    DutchAuctionFinalization public dutchEnd;
    /// @notice Store the mint history for an individual address. Used to issue refunds
    mapping(address => DutchAuctionMintHistory) public mintHistory;
    /// @notice The token id which will be minted next in the dutch auction
    uint public dutchAuctionNextId;

    constructor(uint _DUTCH_AUCTION_START_ID, uint _DUTCH_AUCTION_END_ID) ERC721("Token Name", "SYMBOL") {
        DUTCH_AUCTION_START_ID = _DUTCH_AUCTION_START_ID;
        DUTCH_AUCTION_END_ID = _DUTCH_AUCTION_END_ID;
        dutchAuctionNextId = _DUTCH_AUCTION_START_ID;
        mintingOwner = msg.sender;
        metadataOwner = msg.sender;
        royaltyOwner = msg.sender;
    }

    /// @notice The current dutch auction price
    /// @dev Reverts if dutch auction has not started yet
    /// @dev Returns the end price even if the dutch auction has sold out
    function dutchAuctionPrice() public view returns (uint) {
        DutchAuctionParams memory _params = params;
        uint numIncrements = (block.timestamp - _params.startTime) / _params.timeIncrement;
        uint price = _params.startPrice - numIncrements * _params.priceIncrement;
        if (price < _params.endPrice) {
            price = _params.endPrice;
        }
        return price;
    }

    /// @notice Dutch auction with refunds
    /// @param amount The number of NFTs to mint, either 1 or 2
    function dutchAuctionMint(uint amount) external payable {
        if (amount == 0) {
            revert MintZero();
        }

        DutchAuctionMintHistory memory userMintHistory = mintHistory[msg.sender];

        // Enforce per-account mint cap
        if (userMintHistory.amount + amount > DUTCH_AUCTION_MINT_CAP) {
            revert ExceededUserMintCap();
        }

	uint256 _dutchAuctionNextId = dutchAuctionNextId;
        // Enforce global mint cap
        if (_dutchAuctionNextId + amount > DUTCH_AUCTION_END_ID + 1) {
            revert DutchAuctionOver();
        }

        DutchAuctionParams memory _params = params;

        // Enforce timing
        if (block.timestamp < _params.startTime || _params.startPrice == 0) {
            revert MintNotOpen();
        }
        
        // Calculate dutch auction price
        uint numIncrements = (block.timestamp - _params.startTime) / _params.timeIncrement;
        uint price = _params.startPrice - numIncrements * _params.priceIncrement;
        if (price < _params.endPrice) {
            price = _params.endPrice;
        }

        // Check mint price
        if (msg.value != amount * price) {
            revert FailedToSendEther(msg.sender, address(this));
        }
        unchecked {
            uint128 newPrice = (userMintHistory.amount * userMintHistory.price + uint128(amount * price)) / uint128(userMintHistory.amount + amount);
            mintHistory[msg.sender] = DutchAuctionMintHistory({
                amount: userMintHistory.amount + uint128(amount),
                price: newPrice
            });
            for (uint i = 0; i < amount; ++i) {
                _mint(msg.sender, _dutchAuctionNextId++);
            }
            totalSupply += amount;
            if (_dutchAuctionNextId > DUTCH_AUCTION_END_ID) {
                dutchEnd = DutchAuctionFinalization({
                    price: uint128(price),
                    time: uint128(block.timestamp)
                });
            }
	    dutchAuctionNextId = _dutchAuctionNextId;
        }
    }

    /// @notice Provide dutch auction refunds to people who minted early
    /// @dev Deliberately left unguarded so users can either claim their own, or batch refund others
    function claimDutchAuctionRefund(address[] calldata accounts) external {
        // Check if dutch auction over
        if (dutchEnd.price == 0) {
            revert DutchAuctionNotOver();
        }
        for (uint i = 0; i < accounts.length; ++i) {
            address account = accounts[i];
            DutchAuctionMintHistory memory mint = mintHistory[account];
            // If an account has already been refunded, skip instead of reverting
            // This prevents griefing attacks when performing batch refunds
            if (mint.price > 0) {
                uint refundAmount = mint.amount * (mint.price - dutchEnd.price);
                delete mintHistory[account];
                (bool sent,) = account.call{value: refundAmount}("");
                // Revert if the address has a malicious receive function
                // This is not a griefing vector because the function can be retried
                // without the failing recipient
                if (!sent) {
                    revert FailedToSendEther(address(this), account);
                }
            }
        }
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

    /// @notice Set parameters
    function setDutchAuctionStruct(DutchAuctionParams calldata _params) external {
        if (msg.sender != mintingOwner) {
            revert AccessControl();
        }
        if (!(_params.startPrice >= _params.endPrice && _params.endPrice > 0 && _params.startTime > 0 && _params.timeIncrement > 0)) {
            revert DutchAuctionBadParamsAdmin();
        }
        params = DutchAuctionParams({
            startPrice: _params.startPrice,
            endPrice: _params.endPrice,
            priceIncrement: _params.priceIncrement,
            startTime: _params.startTime,
            timeIncrement: _params.timeIncrement
        });
    }

    /// @notice Claim funds
    function claimFunds(address payable recipient) external {
        if (!(msg.sender == mintingOwner || msg.sender == metadataOwner || msg.sender == royaltyOwner)) {
            revert AccessControl();
        }

        // Wait for the grace period after scheduled end to allow claiming of dutch auction refunds
        if (!(dutchEnd.price > 0 && block.timestamp >= dutchEnd.time + DUTCH_AUCTION_GRACE_PERIOD)) {
            revert DutchAuctionGracePeriod();
        }

        (bool sent,) = recipient.call{value: address(this).balance}("");
        if (!sent) {
            revert FailedToSendEther(address(this), recipient);
        }
    }

    ////////////////////////////////////
    // ACCESS CONTROL ADDRESS UPDATES //
    ////////////////////////////////////

    /// @notice Update the mintingOwner
    /// @dev Can also be used to revoke this power by setting to 0x0
    function setMintingOwner(address _mintingOwner) external {
        if (msg.sender != mintingOwner) {
            revert AccessControl();
        }
        mintingOwner = _mintingOwner;
    }

    /// @notice Update the metadataOwner
    /// @dev Can also be used to revoke this power by setting to 0x0
    /// @dev Should only be revoked after setting an IPFS url so others can pin
    function setMetadataOwner(address _metadataOwner) external {
        if (msg.sender != metadataOwner) {
            revert AccessControl();
        }
        metadataOwner = _metadataOwner;
    }

    /// @notice Update the royaltyOwner
    /// @dev Can also be used to revoke this power by setting to 0x0
    function setRoyaltyOwner(address _royaltyOwner) external {
        if (msg.sender != royaltyOwner) {
            revert AccessControl();
        }
        royaltyOwner = _royaltyOwner;
    }

    /// @notice The address which can set royalties
    function owner() external view returns (address) {
        return royaltyOwner;
    }

    ////////////////////////////
    // METADATA FUNCTIONALITY //
    ////////////////////////////

    /// @notice Returns the metadata URI for a given token
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        return string(abi.encodePacked(baseTokenURI, Strings.toString(tokenId)));
    }
}

