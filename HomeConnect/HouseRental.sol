
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract HouseRental {

struct House {
        uint256 houseId;
        address landlord;
        string description;
        uint256 rentPerDay;
        uint256 deposit;
        uint256 paymentPeriod;
        uint256 minRentalPeriod;
        uint256 maxRentalPeriod;
        uint isAvailable;
    }

struct Rental {
        uint256 rentalId;
        address tenant;
        uint256 houseId;
        uint256 startDate;
        uint256 endDate;
        uint256 dueDate;
        uint256 amountDue;
        uint256 totalAmountDue;
        uint isActive;
    }   
struct Request {
        uint256 requestId;
        address tenant;
        uint256 houseId;
        uint256 startDate;
        uint256 endDate;
        uint isAccepted;
    }   

    House[] public houses;
    Rental[] public rentals;
    mapping(address => Request[]) public requests;
    mapping(address => House[]) public landlordHouses;
    mapping(address => Rental[]) public tenantRentals;

    event HouseListed(uint256 houseId, address landlord);
    event RequestSent(address tenant, uint256 requestId);
    event RequestAccepted(address landlord,address tenant, uint256 housId);
    event HouseRented(uint256 rentalId, address tenant, address landlord, uint256 houseId, uint256 startDate, uint256 endDate);
    event RentalCompleted(uint256 rentalId, address tenant, uint256 houseId);
    event RentPaid(uint256 rentalId,address tenant, uint256 amount);
    event RentalCompleted(uint256 rentalId, address tenant);

/////////////
function listHouse(string memory description, uint256 rentPerDay, uint256 deposit,
                   uint256 paymentPeriod,uint256 minRentalPeriod,uint256 maxRentalPeriod) public {
    uint256 houseId = houses.length ;
    houses.push(House({
        houseId: houseId,
        landlord: msg.sender,
        description: description,
        rentPerDay: rentPerDay,
        deposit: deposit,
        paymentPeriod: paymentPeriod,
        minRentalPeriod: minRentalPeriod,
        maxRentalPeriod: maxRentalPeriod,
        isAvailable: 1
    }));
    landlordHouses[msg.sender].push(houses[houseId]);
    emit HouseListed(houseId, msg.sender);
}

function getAllHouses() public view returns(House[] memory){

    return houses ;
}

//////////////////

function  sendRequest (uint256 houseId,uint256 startDate, uint256 endDate) public {
    require(houses[houseId].isAvailable == 1, "House is not available");
    uint256 rentalPeriod = startDate-endDate;
    require(houses[houseId].maxRentalPeriod>rentalPeriod && rentalPeriod >houses[houseId].minRentalPeriod);
    address landlord = houses[houseId].landlord ; 
    uint256 requestId = requests[landlord].length ;
    requests[landlord].push(Request({requestId: requestId,tenant: msg.sender, houseId: houseId, startDate: startDate, endDate: endDate, isAccepted:0}));
    emit RequestSent(msg.sender, requestId);
}

function getRequests () public view returns (Request[] memory) {

    return requests[msg.sender] ;
}

function acceptRequest (uint256 requestId) public {
    uint256 houseId = requests[msg.sender][requestId].houseId;
    require(houses[houseId].isAvailable == 1, "another request has already been accepted!");
    address tenant = requests[msg.sender][requestId].tenant;
    requests[msg.sender][requestId].isAccepted = 1 ;
    houses[houseId].isAvailable = 2 ;
    emit RequestAccepted (msg.sender, tenant, houseId);

}


function rentHouse(uint256 requestId, uint256 houseId, uint256 startDate, uint256 endDate) public payable {
    address landlord= houses[houseId].landlord ;
    require(requests[landlord][requestId].isAccepted == 1, "your request hasn't been accepted");
    uint256 paymentPeriod = houses[houseId].paymentPeriod ;
    uint256 rentPerDay= houses[houseId].rentPerDay ;
    uint256 deposit = houses[houseId].deposit;
    require(msg.value == rentPerDay *paymentPeriod + deposit, "Incorrect payment ");

    // Convert seconds to days (86400 seconds in a day)
    uint256 numberOfPeriods = ((startDate - endDate) / 86400/ paymentPeriod)+1;
    uint256 dueDate = startDate + paymentPeriod* 86400 ;
    uint256 totalAmountDue = (numberOfPeriods-1)*paymentPeriod * rentPerDay ;
    uint256 rentalId = rentals.length;
    rentals.push(Rental({
        rentalId: rentalId,
        tenant: msg.sender,
        houseId: houseId,
        startDate: startDate,
        endDate: endDate,
        dueDate: dueDate,
        amountDue: 0,
        totalAmountDue: totalAmountDue,
        isActive: 1
    }));

    tenantRentals[msg.sender].push(rentals[rentalId]);
    houses[houseId].isAvailable = 0;
    
    payable(houses[houseId].landlord).transfer(msg.value - houses[houseId].deposit); // Pay rent to the landlord, keep deposit in the contract
    emit HouseRented(rentalId, msg.sender, landlord, houseId, startDate, endDate);
}

function updateRentalData(address tenant) public  {
    uint256 currentDate = block.timestamp ; 
    for (uint256 i = 0; i < tenantRentals[tenant].length; i++) {

        if(tenantRentals[tenant][i].isActive==1){
            uint256 dueDate = tenantRentals[tenant][i].dueDate;
            
            while(currentDate > dueDate){
                Rental memory rental = tenantRentals[tenant][i];
                uint256 houseId = rental.houseId;
                uint256 paymentPeriod = houses[houseId].paymentPeriod;
                uint256 rentPerDay = houses[houseId].rentPerDay;
                tenantRentals[tenant][i].dueDate+= paymentPeriod*86400;
                tenantRentals[tenant][i].amountDue+= paymentPeriod*rentPerDay;
                if(tenantRentals[tenant][i].dueDate>tenantRentals[tenant][i].endDate){
                    tenantRentals[tenant][i].isActive=0;
                    break;
                }
                dueDate = tenantRentals[tenant][i].dueDate;
            }
        }
    }
 

}

function getRentalData() public returns (Rental[] memory) {

   updateRentalData(msg.sender);
   return tenantRentals[msg.sender]; 
}

function payRent(uint256 rentalId) public payable {

    require(rentals[rentalId].amountDue > 0, "You don't have an amount due yet!");
    uint256 houseId = rentals[rentalId].houseId;
    payable(houses[houseId].landlord).transfer(msg.value);
    rentals[rentalId].amountDue-=msg.value ;
    rentals[rentalId].totalAmountDue-=msg.value ;
    emit RentPaid(rentalId,msg.sender,msg.value);

    if (rentals[rentalId].totalAmountDue==0){
    payable(msg.sender).transfer(houses[houseId].deposit);    
    emit RentalCompleted(rentalId, msg.sender);

    }
}

//////////////

}
