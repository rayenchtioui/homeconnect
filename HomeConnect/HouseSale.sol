// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract HouseSale {
    using SafeMath for uint256;

    struct House {
        uint256 id;
        string location;
        uint256 size;
        uint256 price;
        bool isForSale;
        address owner;
    }

    mapping(uint256 => House) public houses;
    uint256 public houseCount;

    event HouseListed(uint256 indexed id, string location, uint256 size, uint256 price, address owner);
    event PriceChanged(uint256 indexed id, uint256 newPrice);
    event HouseSold(uint256 indexed id, address oldOwner, address newOwner, uint256 price);

    modifier onlyOwner(uint256 _houseId) {
    require(msg.sender == houses[_houseId].owner, "You are not the owner");
    _;
}


    modifier forSale(uint256 _houseId) {
        require(houses[_houseId].isForSale, "House is not for sale");
        _;
    }

    function listHouseForSale(string memory _location, uint256 _size, uint256 _price) public {
        houseCount++;
        houses[houseCount] = House({
            id: houseCount,
            location: _location,
            size: _size,
            price: _price,
            isForSale: true,
            owner: msg.sender
        });

        emit HouseListed(houseCount, _location, _size, _price, msg.sender);
    }

    function viewHouse(uint256 _houseId) public view returns (House memory) {
        return houses[_houseId];
    }

    function changePrice(uint256 _houseId, uint256 _newPrice) public onlyOwner(_houseId) forSale(_houseId) {
        houses[_houseId].price = _newPrice;
        emit PriceChanged(_houseId, _newPrice);
    }

    function buyHouse(uint256 _houseId) public payable forSale(_houseId) onlyOwner(_houseId) {
    require(msg.value >= houses[_houseId].price, "Insufficient funds");
    require(houses[_houseId].owner != address(0), "House has no owner");

    address oldOwner = houses[_houseId].owner;

    // Transfer ownership
    houses[_houseId].owner = msg.sender;
    houses[_houseId].isForSale = false;

    // Transfer funds to the old owner
    payable(oldOwner).transfer(msg.value);

    emit HouseSold(_houseId, oldOwner, msg.sender, msg.value);
}


}
