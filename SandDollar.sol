pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";


contract SandDollar is ERC20, Ownable, ReentrancyGuard, ERC20Burnable{
    //can set eth price
    address public oracle;

    uint coinPrice;
    uint priceLastSet;

    struct Vault{
        address owner;
        uint bal;
        uint debt; //in stable coins
    }

    uint numVaults;
    mapping(uint => Vault) vaults;
    
    constructor() ERC20("Sand Dollar", "SDOL"){
       oracle = msg.sender;
    }

    function oracleSetCoinPrice(uint price) public onlyOwner(){
        coinPrice = price;
    }

    function createVault() public nonReentrant(){
        Vault memory myVault = Vault(msg.sender, 0, 0);
        
        vaults[numVaults] = myVault;
        numVaults = numVaults + 1;
    }

    function deposit(uint vaultId) public payable nonReentrant(){
        require(msg.sender == vaults[vaultId].owner);
        vaults[vaultId].bal += msg.value;
    }

    function borrow(uint vaultId, uint amount) public nonReentrant(){
        require(msg.sender == vaults[vaultId].owner);
        require(vaults[vaultId].bal * coinPrice < amount / 100 * 75);
        //max loan is 75% of collateral

        

        _mint(msg.sender, amount);
    }

    function repayDebt(uint vaultId, uint amount) public nonReentrant(){
        require(amount <= vaults[vaultId].debt);
        require(msg.sender == vaults[vaultId].owner);

        //transfer amount from sender to burn
        //reduce debt by that much
        burnFrom(msg.sender, amount);
        vaults[vaultId].debt -= amount;
    }

    function liquidate(uint vaultId) public nonReentrant(){
        require(vaults[vaultId].bal * coinPrice <  vaults[vaultId].debt * 110 / 100);
        //this vault should be liquidated when value < 110% debt
        //example: value of vault = $100, debt = $105. 
        burnFrom(msg.sender, vaults[vaultId].debt);
        
        
        address payable liquidator = payable(msg.sender);
        (bool sent, bytes memory data) = liquidator.call{value: vaults[vaultId].bal * 95 / 100 }("");
        //5% fee
        require(sent, "Failed to send Reef");
        
        vaults[vaultId].debt = 0;
        vaults[vaultId].bal = 0;
    }
}
