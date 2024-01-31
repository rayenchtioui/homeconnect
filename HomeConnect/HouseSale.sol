// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

contract HouseSale {
    struct House {
        uint256 id;
        string location;
        uint256 size;
        uint256 price;
        bool isForSale;
        address owner;
    }

    struct Escrow {
        address buyer;
        uint256 amount;
        bool fundsReleased;
    }

    struct ApprovedBuyer {
        address buyer;
        bool isApproved;
    }

    struct Offer {
        address buyer;
        uint256 offerPrice;
        bool isAccepted;
    }

    mapping(uint256 => House) public houses;
    mapping(uint256 => Escrow) public houseEscrows;
    mapping(uint256 => ApprovedBuyer) public approvedBuyers;
    mapping(uint256 => Offer) public houseOffers;

    uint256 public houseCount;

    event HouseListed(uint256 indexed id, string location, uint256 size, uint256 price, address owner);
    event PriceChanged(uint256 indexed id, uint256 newPrice);
    event HouseSold(uint256 indexed id, address oldOwner, address newOwner, uint256 price);
    event OfferAccepted(uint256 indexed id, address buyer, uint256 offerPrice);
    event ListingCancelled(uint256 indexed id);
    event OfferMade(uint256 indexed id, address buyer, uint256 offerPrice);

    modifier onlyOwner(uint256 _houseId) {
        require(msg.sender == houses[_houseId].owner, "You are not the owner");
        _;
    }

    modifier forSale(uint256 _houseId) {
        require(houses[_houseId].isForSale, "House is not for sale");
        _;
    }

    function listHouseForSale(string memory _location, uint256 _size, uint256 _price) public {
        houseCount = houseCount + 1;
        require(!houses[houseCount].isForSale, "House already listed");
        houses[houseCount] = House(houseCount, _location, _size, _price, true, msg.sender);
        emit HouseListed(houseCount, _location, _size, _price, msg.sender);
    }

    function viewHouse(uint256 _houseId) public view returns (House memory) {
        require(_houseId <= houseCount && _houseId > 0, "House does not exist");
        return houses[_houseId];
    }

    function changePrice(uint256 _houseId, uint256 _newPrice) public onlyOwner(_houseId) forSale(_houseId) {
        houses[_houseId].price = _newPrice;
        emit PriceChanged(_houseId, _newPrice);
    }

    function buyHouse(uint256 _houseId) public payable forSale(_houseId) {
        House storage house = houses[_houseId];
        require(msg.value >= house.price, "Insufficient funds");
        require(house.owner != address(0), "House has no owner");
        require(approvedBuyers[_houseId].isApproved && approvedBuyers[_houseId].buyer == msg.sender, "Buyer not approved");

        address oldOwner = house.owner;
        house.owner = msg.sender;
        house.isForSale = false;
        houseEscrows[_houseId] = Escrow(msg.sender, msg.value, true);

        payable(oldOwner).transfer(msg.value);
        emit HouseSold(_houseId, oldOwner, msg.sender, msg.value);
    }

    function approveBuyer(uint256 _houseId, address _buyer) public onlyOwner(_houseId) {
        approvedBuyers[_houseId] = ApprovedBuyer({
            buyer: _buyer,
            isApproved: true
        });
    }

    function resetApproval(uint256 _houseId) public onlyOwner(_houseId) {
        approvedBuyers[_houseId].isApproved = false;
        approvedBuyers[_houseId].buyer = address(0);
    }

    function makeOffer(uint256 _houseId, uint256 _offerPrice) public {
        houseOffers[_houseId] = Offer({
            buyer: msg.sender,
            offerPrice: _offerPrice,
            isAccepted: false
        });
        emit OfferMade(_houseId, msg.sender, _offerPrice);
    }

    function acceptOffer(uint256 _houseId) public onlyOwner(_houseId) {
        require(houseOffers[_houseId].offerPrice > 0, "No valid offer made");
        approveBuyer(_houseId, houseOffers[_houseId].buyer);
        houses[_houseId].price = houseOffers[_houseId].offerPrice;
        houseOffers[_houseId].isAccepted = true;
        emit OfferAccepted(_houseId, houseOffers[_houseId].buyer, houseOffers[_houseId].offerPrice);
    }

    function cancelListing(uint256 _houseId) public onlyOwner(_houseId) {
        require(houses[_houseId].isForSale, "House is not currently for sale");
        houses[_houseId].isForSale = false;
        resetApproval(_houseId);
        emit ListingCancelled(_houseId);
    }

    function listHousesForSale() public view returns (uint256[] memory, string[] memory, uint256[] memory) {
    uint256 forSaleCount = 0;

    for (uint256 i = 1; i <= houseCount; i++) {
        if (houses[i].isForSale) {
            forSaleCount++;
        }
    }

    uint256[] memory ids = new uint256[](forSaleCount);
    string[] memory locations = new string[](forSaleCount);
    uint256[] memory prices = new uint256[](forSaleCount);

    uint256 currentIndex = 0;

    for (uint256 i = 1; i <= houseCount; i++) {
        if (houses[i].isForSale) {
            ids[currentIndex] = houses[i].id;
            locations[currentIndex] = houses[i].location;
            prices[currentIndex] = houses[i].price;
            currentIndex++;
        }
    }

    return (ids, locations, prices);
}
}
