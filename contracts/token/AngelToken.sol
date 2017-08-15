pragma solidity ^0.4.13;


import "zeppelin-solidity/contracts/token/StandardToken.sol";
import "../utils/Manageable.sol";
import "../utils/Pausable.sol";
import "../CentralBank/CentralBank.sol";
import "./NamedToken.sol";


/**
 * @title AngelToken
 */
contract AngelToken is StandardToken, NamedToken, Pausable {

  /* Events */

  event MintEvent(address indexed account, uint value);
  event BurnEvent(address indexed account, uint value);
  event SpendingBlockedEvent(address indexed account);
  event SpendingUnblockedEvent(address indexed account);


  /* Storage */

  address public centralBankAddress;
  mapping (address => bool) spendingBlocked;


  /* Constructor */

  function AngelToken() NamedToken('Angel Token', 'ANT', 18) {
    centralBankAddress = msg.sender;
  }


  /* Methods */

  function transfer(address _to, uint _value) returns (bool) {
    if (_to != centralBankAddress) {
      require(!paused);
    }
    require(spendingBlocked[msg.sender] == false);

    bool result = super.transfer(_to, _value);
    if (result == true && _to == centralBankAddress) {
      CentralBank(centralBankAddress).angelBurn(msg.sender, _value);
    }
    return result;
  }

  function approve(address _spender, uint _value) whenContractNotPaused returns (bool){
    return super.approve(_spender, _value);
  }

  function transferFrom(address _from, address _to, uint _value) whenContractNotPaused returns (bool){
    require(spendingBlocked[_from] == false);

    bool result = super.transferFrom(_from, _to, _value);
    if (result == true && _to == centralBankAddress) {
      CentralBank(centralBankAddress).angelBurn(_from, _value);
    }
    return result;
  }


  function mint(address _account, uint _value) onlyAllowedManager('mint_tokens') {
    balances[_account] = balances[_account].add(_value);
    totalSupply = totalSupply.add(_value);
    MintEvent(_account, _value);
  }

  function burn(uint _value) onlyAllowedManager('burn_tokens') {
    balances[msg.sender] = balances[msg.sender].sub(_value);
    totalSupply = totalSupply.sub(_value);
    BurnEvent(msg.sender, _value);
  }

  function blockSpending(address _account) onlyAllowedManager('block_spending') {
    spendingBlocked[_account] = true;
    SpendingBlockedEvent(_account);
  }

  function unblockSpending(address _account) onlyAllowedManager('unblock_spending') {
    spendingBlocked[_account] = false;
    SpendingUnblockedEvent(_account);
  }

  modifier whenAccountNotBlocked(address _account) {
    require(spendingBlocked[_account] == false);
    _;
  }
}
