pragma solidity ^0.4.15;


import "zeppelin-solidity/contracts/token/StandardToken.sol";
import "../utils/Manageable.sol";
import "../utils/Pausable.sol";
import "../token/NamedToken.sol";
import "./AngelCentralBank.sol";


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
  mapping (address => uint) spendingBlocksNumber;


  /* Constructor */

  function AngelToken() NamedToken('ANGEL', 'ANG', 18) {
    centralBankAddress = msg.sender;
  }


  /* Methods */

  function transfer(address _to, uint _value) returns (bool) {
    if (_to != centralBankAddress) {
      require(!paused);
    }
    require(spendingBlocksNumber[msg.sender] == 0);

    bool result = super.transfer(_to, _value);
    if (result == true && _to == centralBankAddress) {
      AngelCentralBank(centralBankAddress).angelBurn(msg.sender, _value);
    }
    return result;
  }

  function approve(address _spender, uint _value) whenContractNotPaused returns (bool){
    return super.approve(_spender, _value);
  }

  function transferFrom(address _from, address _to, uint _value) whenContractNotPaused returns (bool){
    require(spendingBlocksNumber[_from] == 0);

    bool result = super.transferFrom(_from, _to, _value);
    if (result == true && _to == centralBankAddress) {
      AngelCentralBank(centralBankAddress).angelBurn(_from, _value);
    }
    return result;
  }


  function mint(address _account, uint _value) onlyAllowedManager('mint_tokens') {
    balances[_account] = balances[_account].add(_value);
    totalSupply = totalSupply.add(_value);
    MintEvent(_account, _value);
    Transfer(address(0x0), _account, _value); // required for blockexplorers
  }

  function burn(uint _value) onlyAllowedManager('burn_tokens') {
    balances[msg.sender] = balances[msg.sender].sub(_value);
    totalSupply = totalSupply.sub(_value);
    BurnEvent(msg.sender, _value);
  }

  function blockSpending(address _account) onlyAllowedManager('block_spending') {
    spendingBlocksNumber[_account] = spendingBlocksNumber[_account].add(1);
    SpendingBlockedEvent(_account);
  }

  function unblockSpending(address _account) onlyAllowedManager('unblock_spending') {
    spendingBlocksNumber[_account] = spendingBlocksNumber[_account].sub(1);
    SpendingUnblockedEvent(_account);
  }
}
