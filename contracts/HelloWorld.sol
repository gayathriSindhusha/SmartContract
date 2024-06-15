// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract EscrowContract {
    address public owner;
    uint256 public disputeTimeout = 2 minutes; // Example dispute resolution period

    struct Item {
        string name;
        uint256 price;
        address payable seller;
        address buyer;
        bool isSold;
        bool isDisputed;
        uint256 purchaseTime;
    }

    mapping(string => Item) public items;

    event ItemListed(string indexed itemName, uint256 price, address indexed seller);
    event ItemBought(string indexed itemName, address indexed buyer, uint256 price);
    event ItemReceived(string indexed itemName, address indexed buyer);
    event DisputeResolved(string indexed itemName, address indexed resolver);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    modifier onlyBuyer(string memory _itemName) {
        require(msg.sender == items[_itemName].buyer, "Only buyer can call this function");
        _;
    }

    modifier onlySeller(string memory _itemName) {
        require(msg.sender == items[_itemName].seller, "Only seller can call this function");
        _;
    }

    modifier itemExists(string memory _itemName) {
        require(items[_itemName].seller != address(0), "Item does not exist");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function listItem(string memory _itemName, uint256 _price) public {
        require(items[_itemName].seller == address(0), "Item already listed");
        require(_price > 0, "Price must be greater than 0");

        items[_itemName] = Item({
            name: _itemName,
            price: _price,
            seller: payable(msg.sender),
            buyer: address(0),
            isSold: false,
            isDisputed: false,
            purchaseTime: 0
        });

        emit ItemListed(_itemName, _price, msg.sender);
    }

    function buy(string memory _itemName) public payable itemExists(_itemName) {
        Item storage item = items[_itemName];
        require(!item.isSold, "Item already sold");
        require(msg.value == item.price, string(abi.encodePacked("Incorrect price sent: expected ", uint2str(item.price), " wei, but got ", uint2str(msg.value), " wei")));

        item.buyer = msg.sender;
        item.isSold = true;
        item.purchaseTime = block.timestamp;

        emit ItemBought(_itemName, msg.sender, msg.value);
    }

    function Confirmation(string memory _itemName) public onlyBuyer(_itemName) itemExists(_itemName) {
        Item storage item = items[_itemName];
        require(item.isSold, "Item not sold");
        require(!item.isDisputed, "Item is under dispute");

        item.seller.transfer(item.price);

        emit ItemReceived(_itemName, msg.sender);
    }

    function initiateDispute(string memory _itemName) public onlyBuyer(_itemName) itemExists(_itemName) {
        Item storage item = items[_itemName];
        require(item.isSold, "Item not sold");
        item.isDisputed = true;
    }

    function resolveDispute(string memory _itemName, bool _refundBuyer) public onlyOwner itemExists(_itemName) {
        Item storage item = items[_itemName];
        require(item.isSold, "Item not sold");
        require(item.isDisputed, "No dispute to resolve");
        require(block.timestamp >= item.purchaseTime + disputeTimeout, "Dispute period not over");

        if (_refundBuyer) {
            payable(item.buyer).transfer(item.price);
        } else {
            item.seller.transfer(item.price);
        }

        item.isDisputed = false;

        emit DisputeResolved(_itemName, msg.sender);
    }

    function getItemDetails(string memory _itemName) public view itemExists(_itemName) returns (Item memory) {
        return items[_itemName];
    }

    // Utility function to convert uint to string
    function uint2str(uint _i) internal pure returns (string memory) {
        if (_i == 0) {
            return "0";
        }
        uint j = _i;
        uint len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint k = len;
        while (_i != 0) {
            k = k-1;
            uint8 temp = (48 + uint8(_i - _i / 10 * 10));
            bytes1 b1 = bytes1(temp);
            bstr[k] = b1;
            _i /= 10;
        }
        return string(bstr);
    }
}