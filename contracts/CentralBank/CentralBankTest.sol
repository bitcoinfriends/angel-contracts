pragma solidity ^0.4.13;


import 'zeppelin-solidity/contracts/math/SafeMath.sol';
import '../token/AngelToken.sol';


/**
 * @title CentralBank
 *
 * @dev Crowdsale and escrow contract
 */
contract CentralBankTest is CentralBank {

  /* Constructor and config */

  function setICOConfig(
    address _newFoundationAddress,
    uint _icoLaunchTimestamp,
    uint _icoFinishTimestamp,
    uint _firstRefundRoundFinishTimestamp,
    uint _secondRefundRoundFinishTimestamp
  ) {
    require(msg.sender == angelFoundationAddress || msg.sender == angelAdminAddress);
    require(_newFoundationAddress != address(0x0));
    require(_icoFinishTimestamp > _icoLaunchTimestamp);
    require(_firstRefundRoundFinishTimestamp > _icoLaunchTimestamp);
    require(_secondRefundRoundFinishTimestamp > _firstRefundRoundFinishTimestamp);

    angelFoundationAddress = _newFoundationAddress;
    icoLaunchTimestamp = _icoLaunchTimestamp;
    icoFinishTimestamp = _icoFinishTimestamp;
    firstRefundRoundFinishTimestamp = _firstRefundRoundFinishTimestamp;
    secondRefundRoundFinishTimestamp = _secondRefundRoundFinishTimestamp;
  }

  function setTokenPrice(uint _initialTokenPrice) {
    require(msg.sender == angelFoundationAddress || msg.sender == angelAdminAddress);

    initialTokenPrice = _initialTokenPrice;
  }


  function validateInvestmentRecord(
    address _investor,
    uint _recordIndex,
    uint _tokensSoldBeforeWei,
    uint _investedEthWei,
    uint _purchasedTokensWei,
    uint _refundedEthWei,
    uint _returnedTokensWei
  )
    constant returns (bool)
  {
    return investments[_investor][_recordIndex].tokensSoldBeforeWei == _tokensSoldBeforeWei &&
           investments[_investor][_recordIndex].investedEthWei == _investedEthWei &&
           investments[_investor][_recordIndex].purchasedTokensWei == _purchasedTokensWei &&
           investments[_investor][_recordIndex].refundedEthWei == _refundedEthWei &&
           investments[_investor][_recordIndex].returnedTokensWei == _returnedTokensWei;
  }


  function selfDestruct() {
    require(msg.sender == angelFoundationAddress || msg.sender == angelAdminAddress);
    selfdestruct(angelAdminAddress);
  }
}
