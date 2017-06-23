pragma solidity ^0.4.13;


import "zeppelin-solidity/contracts/lifecycle/Pausable.sol";
import "zeppelin-solidity/contracts/token/StandardToken.sol";
import "./NamedToken.sol";
import "../CentralBank/CentralBank.sol";


/**
 * @title AngelToken
 */
contract AngelToken is StandardToken, Pausable, NamedToken {

  /* Events */

  event MintEvent(address indexed account, uint value);
  event BurnEvent(address indexed account, uint value);


  /* Storage */

  address public centralBankAddress;


  /* Constructor */

  function AngelToken() NamedToken('Angel Token', 'ANT', 18) {
    centralBankAddress = msg.sender;
  }


  /* Methods */

  function transfer(address _to, uint _value) returns (bool) {
    if (_to != centralBankAddress) {
      require(!paused);
    }
    bool result = super.transfer(_to, _value);
    if (result == true && _to == centralBankAddress) {
      CentralBank(centralBankAddress).angelBurn(msg.sender, _value);
    }
    return result;
  }

  function approve(address _spender, uint _value) whenNotPaused returns (bool){
    return super.approve(_spender, _value);
  }

  function transferFrom(address _from, address _to, uint _value) whenNotPaused returns (bool){
    bool result = super.transferFrom(_from, _to, _value);
    if (result == true && _to == centralBankAddress) {
      CentralBank(centralBankAddress).angelBurn(_from, _value);
    }
    return result;
  }

  function mint(address _account, uint _value) onlyOwner {
    balances[_account] = balances[_account].add(_value);
    totalSupply = totalSupply.add(_value);
    MintEvent(_account, _value);
  }

  function burn(uint _value) {
    balances[msg.sender] = balances[msg.sender].sub(_value);
    totalSupply = totalSupply.sub(_value);
    BurnEvent(msg.sender, _value);
  }
}
