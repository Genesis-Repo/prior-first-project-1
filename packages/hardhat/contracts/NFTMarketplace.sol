// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Importing necessary libraries from OpenZeppelin
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract NFTMarketplace is ERC721Holder, Ownable {
    // State variable to store the fee percentage
    uint256 public feePercentage;
    uint256 private constant PERCENTAGE_BASE = 100;

    // Structure to store statistics of NFTs listed and sold
    struct Listing {
        address seller;
        uint256 price;
        bool isActive;
    }

    // Mapping to store listings of NFTs
    mapping(address => mapping(uint256 => Listing)) private listings;

    // Events to emit for different actions
    event NFTListed(address indexed seller, uint256 indexed tokenId, uint256 price);
    event NFTSold(address indexed seller, address indexed buyer, uint256 indexed tokenId, uint256 price);
    event NFTPriceChanged(address indexed seller, uint256 indexed tokenId, uint256 newPrice);
    event NFTUnlisted(address indexed seller, uint256 indexed tokenId);
    
    // Event to track statistics 
    event NFTStatsUpdated(address indexed nftContract, uint256 totalListings, uint256 totalSales);

    // Constructor to set the default fee percentage
    constructor() {
        feePercentage = 2;  // Setting the default fee percentage to 2%
    }

    // Function to list an NFT for sale
    function listNFT(address nftContract, uint256 tokenId, uint256 price) external {
        require(price > 0, "Price must be greater than zero");

        // Transfer the NFT from the seller to the marketplace contract
        IERC721(nftContract).safeTransferFrom(msg.sender, address(this), tokenId);

        // Create a new listing
        listings[nftContract][tokenId] = Listing({
            seller: msg.sender,
            price: price,
            isActive: true
        });

        emit NFTListed(msg.sender, tokenId, price);
        
        // Emit stats event after listing
        emit NFTStatsUpdated(nftContract, getNumberOfListings(nftContract), getNumberOfSales(nftContract));
    }

    // Function to buy an NFT listed on the marketplace
    function buyNFT(address nftContract, uint256 tokenId) external payable {
        Listing storage listing = listings[nftContract][tokenId];
        require(listing.isActive, "NFT is not listed for sale");
        require(msg.value >= listing.price, "Insufficient payment");

        // Calculate and transfer the fee to the marketplace owner
        uint256 feeAmount = (listing.price * feePercentage) / PERCENTAGE_BASE;
        uint256 sellerAmount = listing.price - feeAmount;
        payable(owner()).transfer(feeAmount); // Transfer fee to marketplace owner

        // Transfer the remaining amount to the seller
        payable(listing.seller).transfer(sellerAmount);

        // Transfer the NFT from the marketplace contract to the buyer
        IERC721(nftContract).safeTransferFrom(address(this), msg.sender, tokenId);

        // Update the listing
        listing.isActive = false;

        emit NFTSold(listing.seller, msg.sender, tokenId, listing.price);
        
        // Emit stats event after sale
        emit NFTStatsUpdated(nftContract, getNumberOfListings(nftContract), getNumberOfSales(nftContract));
    }

    // Function to change the price of a listed NFT
    function changePrice(address nftContract, uint256 tokenId, uint256 newPrice) external {
        require(newPrice > 0, "Price must be greater than zero");
        require(listings[nftContract][tokenId].seller == msg.sender, "You are not the seller");

        listings[nftContract][tokenId].price = newPrice;

        emit NFTPriceChanged(msg.sender, tokenId, newPrice);
    }

    // Function to unlist a listed NFT
    function unlistNFT(address nftContract, uint256 tokenId) external {
        require(listings[nftContract][tokenId].seller == msg.sender, "You are not the seller");

        delete listings[nftContract][tokenId];

        // Transfer the NFT back to the seller
        IERC721(nftContract).safeTransferFrom(address(this), msg.sender, tokenId);

        emit NFTUnlisted(msg.sender, tokenId);
        
        // Emit stats event after unlisting
        emit NFTStatsUpdated(nftContract, getNumberOfListings(nftContract), getNumberOfSales(nftContract));
    }

    // Function to set the fee percentage by the marketplace owner
    function setFeePercentage(uint256 newFeePercentage) external onlyOwner {
        require(newFeePercentage < PERCENTAGE_BASE, "Fee percentage must be less than 100");

        feePercentage = newFeePercentage;
    }

    // Function to get the number of listings for a specific NFT contract
    function getNumberOfListings(address nftContract) public view returns (uint256) {
        uint256 count;
        for (uint256 i = 0; i < IERC721(nftContract).balanceOf(address(this)); i++) {
            if (listings[nftContract][i].isActive) {
                count++;
            }
        }
        return count;
    }

    // Function to get the number of sales for a specific NFT contract
    function getNumberOfSales(address nftContract) public view returns (uint256) {
        uint256 count;
        for (uint256 i = 0; i < IERC721(nftContract).balanceOf(address(this)); i++) {
            if (!listings[nftContract][i].isActive) {
                count++;
            }
        }
        return count;
    }
}