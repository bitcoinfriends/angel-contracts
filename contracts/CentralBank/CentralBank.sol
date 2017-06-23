pragma solidity ^0.4.13;


import 'zeppelin-solidity/contracts/math/SafeMath.sol';
import '../token/AngelToken.sol';


/**
 * @title CentralBank
 *
 * @dev Crowdsale and escrow contract
 */
contract CentralBank {

  /* Data structures */

  struct InvestmentRecord {
    uint tokensSoldBeforeWei;
    uint investedEthWei;
    uint purchasedTokensWei;
    uint refundedEthWei;
    uint returnedTokensWei;
  }


  /* Storage - config */

  uint public icoCap = 70000000 * (10 ** 18);

  uint public initialTokenPrice = 1 * (10 ** 18) / (10 ** 4); // means 0.0001 ETH for one token

  uint public landmarkSize = 1000000 * (10 ** 18);
  uint public landmarkPriceStep = 1 * (10 ** 18) / (10 ** 5);

  uint public icoDuration = 30 days;
  uint public firstRefundRoundDuration = 100 days;
  uint public secondRefundRoundDuration = 100 days;

  uint public firstRefundRoundRateNumerator = 80;
  uint public firstRefundRoundRateDenominator = 100;
  uint public secondRefundRoundRateNumerator = 40;
  uint public secondRefundRoundRateDenominator = 100;

  uint public initialFundsReleaseNumerator = 20; // part of investment
  uint public initialFundsReleaseDenominator = 100;
  uint public afterFirstRefundRoundFundsReleaseNumerator = 50; // part of remaining funds
  uint public afterFirstRefundRoundFundsReleaseDenominator = 100;

  uint public angelFoundationShareNumerator = 30;
  uint public angelFoundationShareDenominator = 100;

  /* Storage - state */

  bool public isICOConfigured = false;
  address public angelAdminAddress;
  address public angelFoundationAddress = address(0x0);
  uint public icoLaunchTimestamp;
  uint public icoFinishTimestamp;
  uint public firstRefundRoundFinishTimestamp;
  uint public secondRefundRoundFinishTimestamp;

  AngelToken public angelToken;

  mapping (address => InvestmentRecord[]) public investments; // investorAddress => list of investments
  uint public totalTokensSold = 0;

  bool angelTokenUnpaused = false;
  bool firstRefundRoundFundsWithdrawal = false;


  /* Events */

  event InvestmentEvent(address indexed investor, uint eth, uint angel);
  event RefundEvent(address indexed investor, uint eth, uint angel);


  /* Constructor and config */

  function CentralBank() {
    angelAdminAddress = msg.sender;

    icoLaunchTimestamp = now;
    icoFinishTimestamp = icoLaunchTimestamp + icoDuration;
    firstRefundRoundFinishTimestamp = icoFinishTimestamp + firstRefundRoundDuration;
    secondRefundRoundFinishTimestamp = firstRefundRoundFinishTimestamp + secondRefundRoundDuration;

    angelToken = new AngelToken();
    angelToken.pause();
  }

  function setICOConfig(
    address _newFoundationAddress,
    uint _icoLaunchTimestamp,
    uint _icoDuration,
    uint _firstRefundRoundDuration,
    uint _secondRefundRoundDuration
  ) {
    require(_newFoundationAddress != address(0x0));

    if (isICOConfigured == true) {
      require(now < icoLaunchTimestamp);
    }

    if (isICOConfigured == true) {
      require(msg.sender == angelFoundationAddress);
    } else {
      require(msg.sender == angelFoundationAddress || msg.sender == angelAdminAddress);
    }

    isICOConfigured = true;
    angelFoundationAddress = _newFoundationAddress;
    icoLaunchTimestamp = _icoLaunchTimestamp;
    icoFinishTimestamp = icoLaunchTimestamp + _icoDuration;
    firstRefundRoundFinishTimestamp = icoFinishTimestamp + _firstRefundRoundDuration;
    secondRefundRoundFinishTimestamp = firstRefundRoundFinishTimestamp + _secondRefundRoundDuration;
  }

  function setFoundationAddress(address _newFoundationAddress) {
    require(_newFoundationAddress != address(0x0));
    require(msg.sender == angelFoundationAddress);

    angelFoundationAddress = _newFoundationAddress;
  }

  function setAdminAddress(address _newAdminAddress) {
    require(_newAdminAddress != address(0x0));
    require(msg.sender == angelFoundationAddress || msg.sender == angelAdminAddress);

    angelAdminAddress = _newAdminAddress;
  }


  /* Investments */

  /**
   * @dev Fallback function receives ETH and sends tokens back
   */
  function () payable {
    angelRaise();
  }

  /**
   * @dev Process new ETH investment and sends tokens back
   */
  function angelRaise() internal {
    require(isICOConfigured == true);
    require(msg.value >= 0);
    require(now >= icoLaunchTimestamp && now < icoFinishTimestamp);

    // calculate amount of tokens for received ETH
    var _purchasedTokensWei = calculatePurchasedTokens(totalTokensSold, msg.value);

    // create record for the investment
    uint _newRecordIndex = investments[msg.sender].length;
    investments[msg.sender].length += 1;
    investments[msg.sender][_newRecordIndex].tokensSoldBeforeWei = totalTokensSold;
    investments[msg.sender][_newRecordIndex].investedEthWei = msg.value;
    investments[msg.sender][_newRecordIndex].purchasedTokensWei = _purchasedTokensWei;
    investments[msg.sender][_newRecordIndex].refundedEthWei = 0;
    investments[msg.sender][_newRecordIndex].returnedTokensWei = 0;
    totalTokensSold += _purchasedTokensWei;

    // transfer tokens and ETH
    angelToken.mint(msg.sender, _purchasedTokensWei);
    angelToken.mint(angelFoundationAddress,
                    _purchasedTokensWei * angelFoundationShareNumerator / (angelFoundationShareDenominator - angelFoundationShareNumerator));
    angelFoundationAddress.transfer(msg.value * initialFundsReleaseNumerator / initialFundsReleaseDenominator);

    // finish ICO if cap reached
    if (totalTokensSold >= icoCap) {
      uint diff = icoFinishTimestamp - now;
      icoFinishTimestamp = now;
      firstRefundRoundFinishTimestamp -= diff;
      secondRefundRoundFinishTimestamp -= diff;
    }

    // fire event
    InvestmentEvent(msg.sender, msg.value, _purchasedTokensWei);
  }

  /**
   * @dev Calculate amount of tokens for received ETH
   * @param _totalTokensSoldBefore uint Amount of tokens sold before this investment [token wei]
   * @param _investedEthWei        uint Investment amount [ETH wei]
   * @return Purchased amount of tokens [token wei]
   */
  function calculatePurchasedTokens(
    uint _totalTokensSoldBefore,
    uint _investedEthWei)
    constant returns (uint)
  {
    uint _purchasedTokensWei = 0;
    uint _notProcessedEthWei = _investedEthWei;

    uint _landmarkPrice;
    uint _maxLandmarkTokensWei;
    uint _maxLandmarkEthWei;
    do {
      // get landmark values
      _landmarkPrice = calculateLandmarkPrice(_totalTokensSoldBefore + _purchasedTokensWei);
      _maxLandmarkTokensWei = landmarkSize - ((_totalTokensSoldBefore + _purchasedTokensWei) % landmarkSize);
      _maxLandmarkEthWei = _maxLandmarkTokensWei * _landmarkPrice / (10 ** 18);

      // check investment against landmark values
      if (_notProcessedEthWei >= _maxLandmarkEthWei) {
        _purchasedTokensWei += _maxLandmarkTokensWei;
        _notProcessedEthWei -= _maxLandmarkEthWei;
      }
      else {
        _purchasedTokensWei += _notProcessedEthWei * (10 ** 18) / _landmarkPrice;
        _notProcessedEthWei = 0;
      }
    }
    while (_notProcessedEthWei > 0);

    require(_purchasedTokensWei > 0);
    require(_totalTokensSoldBefore + _purchasedTokensWei <= icoCap);

    return _purchasedTokensWei;
  }


  /* Refunds */

  function angelBurn(
    address _investor,
    uint _returnedTokensWei
  )
    returns (uint)
  {
    require(msg.sender == address(angelToken));
    require(now >= icoLaunchTimestamp && now < secondRefundRoundFinishTimestamp);

    uint _notProcessedTokensWei = _returnedTokensWei;
    uint _refundedEthWei = 0;

    uint _allRecordsNumber = investments[_investor].length;
    uint _recordMaxReturnedTokensWei = 0;
    uint _recordTokensWeiToProcess = 0;
    uint _tokensSoldWei = 0;
    uint _recordRefundedEthWei = 0;
    for (uint _recordID = _allRecordsNumber - 1; _recordID >= 0; _recordID -= 1) {
      if (investments[_investor][_recordID].purchasedTokensWei <= investments[_investor][_recordID].returnedTokensWei) {
        // tokens already refunded
        continue;
      }

      // calculate amount of tokens to refund with this record
      _recordMaxReturnedTokensWei = investments[_investor][_recordID].purchasedTokensWei -
                                    investments[_investor][_recordID].returnedTokensWei;
      _recordTokensWeiToProcess = (_notProcessedTokensWei < _recordMaxReturnedTokensWei) ? _notProcessedTokensWei :
                                                                                           _recordMaxReturnedTokensWei;
      _tokensSoldWei = investments[_investor][_recordID].tokensSoldBeforeWei + _recordMaxReturnedTokensWei;
      assert(_recordTokensWeiToProcess > 0);

      // calculate amount of ETH to send back
      _recordRefundedEthWei = calculateRefundedEth(_tokensSoldWei, _recordTokensWeiToProcess);
      if (_recordRefundedEthWei > (investments[_investor][_recordID].investedEthWei - investments[_investor][_recordID].refundedEthWei)) {
        // this can happen due to rounding error
        _recordRefundedEthWei = (investments[_investor][_recordID].investedEthWei - investments[_investor][_recordID].refundedEthWei);
      }
      assert(_recordRefundedEthWei > 0);

      // persist changes to the storage
      _refundedEthWei += _recordRefundedEthWei;
      _notProcessedTokensWei -= _recordTokensWeiToProcess;

      investments[_investor][_recordID].refundedEthWei += _recordRefundedEthWei;
      investments[_investor][_recordID].returnedTokensWei += _recordTokensWeiToProcess;
      assert(investments[_investor][_recordID].refundedEthWei <= investments[_investor][_recordID].investedEthWei);
      assert(investments[_investor][_recordID].returnedTokensWei <= investments[_investor][_recordID].purchasedTokensWei);

      // stop if we already refunded all tokens
      if (_notProcessedTokensWei == 0) {
        break;
      }
    }

    // throw if we do not have tokens to refund
    require(_notProcessedTokensWei < _returnedTokensWei);
    require(_refundedEthWei > 0);

    // calculate refund discount
    uint _refundedEthWeiWithDiscount = calculateRefundedEthWithDiscount(_refundedEthWei);

    // transfer ETH and remaining tokens
    _investor.transfer(_refundedEthWeiWithDiscount);
    angelToken.burn(_returnedTokensWei - _notProcessedTokensWei);
    if (_notProcessedTokensWei > 0) {
      angelToken.transfer(_investor, _notProcessedTokensWei);
    }

    // fire event
    RefundEvent(_investor, _refundedEthWeiWithDiscount, _returnedTokensWei - _notProcessedTokensWei);
  }

  /**
   * @dev Calculate discounted amount of ETH for refunded tokens
   * @param _refundedEthWei uint Calculated amount of ETH to refund [ETH wei]
   * @return Discounted amount of ETH for refunded [ETH wei]
   */
  function calculateRefundedEthWithDiscount(
    uint _refundedEthWei
  )
    constant returns (uint)
  {
    if (now <= firstRefundRoundFinishTimestamp) {
      return (_refundedEthWei * firstRefundRoundRateNumerator / firstRefundRoundRateDenominator);
    }
    else {
      return (_refundedEthWei * secondRefundRoundRateNumerator / secondRefundRoundRateDenominator);
    }
  }

  /**
   * @dev Calculate amount of ETH for refunded tokens. Just abstract price ladder
   * @param _tokensSoldWei     uint Amount of tokens that have been sold (starting point) [token wei]
   * @param _returnedTokensWei uint Amount of tokens to refund [token wei]
   * @return Refunded amount of ETH [ETH wei] (without discounts)
   */
  function calculateRefundedEth(
    uint _tokensSoldWei,
    uint _returnedTokensWei
  )
    constant returns (uint)
  {
    uint _refundedEthWei = 0;
    uint _notProcessedTokensWei = _returnedTokensWei;

    uint _iterStartingPoint = 0;
    uint _landmarkPrice = 0;
    uint _maxLandmarkTokensWei = 0;
    uint _maxLandmarkEthWei = 0;
    do {
      // get landmark values
      _iterStartingPoint = _tokensSoldWei - _returnedTokensWei + _notProcessedTokensWei;
      if (_iterStartingPoint % landmarkSize == 0) {
        _landmarkPrice = calculateLandmarkPrice(_iterStartingPoint - 1);
        _maxLandmarkTokensWei = landmarkSize;
      }
      else {
        _landmarkPrice = calculateLandmarkPrice(_iterStartingPoint);
        _maxLandmarkTokensWei = (_iterStartingPoint % landmarkSize);
      }
      _maxLandmarkEthWei = _maxLandmarkTokensWei * _landmarkPrice / (10 ** 18);

      // check investment against landmark values
      if (_notProcessedTokensWei > _maxLandmarkTokensWei) {
        _refundedEthWei += _maxLandmarkEthWei;
        _notProcessedTokensWei -= _maxLandmarkTokensWei;
      }
      else {
        _refundedEthWei += _notProcessedTokensWei * _landmarkPrice / (10 ** 18);
        _notProcessedTokensWei = 0;
      }
    } while (_notProcessedTokensWei > 0);

    return _refundedEthWei;
  }


  /* Calculation of the price */

  /**
   * @dev Calculate price for tokens
   * @param _totalTokensSoldBefore uint Amount of tokens sold before [token wei]
   * @return Calculated price
   */
  function calculateLandmarkPrice(uint _totalTokensSoldBefore) constant returns (uint) {
    return initialTokenPrice + landmarkPriceStep * (_totalTokensSoldBefore / landmarkSize);
  }


  /* Lifecycle */

  function finishICO() {
    require(totalTokensSold >= icoCap);
    require(icoFinishTimestamp > now);

    uint diff = icoFinishTimestamp - now;
    icoFinishTimestamp = now;
    firstRefundRoundFinishTimestamp -= diff;
    secondRefundRoundFinishTimestamp -= diff;
  }

  function unpauseAngelToken() {
    require(now > icoFinishTimestamp);
    require(angelTokenUnpaused == false);

    angelTokenUnpaused = true;

    angelToken.unpause();
  }

  function withdrawFoundationFunds() {
    require(msg.sender == angelFoundationAddress || msg.sender == angelAdminAddress);
    require(now > firstRefundRoundFinishTimestamp);

    if (now > firstRefundRoundFinishTimestamp && now <= secondRefundRoundFinishTimestamp) {
      require(firstRefundRoundFundsWithdrawal == false);

      firstRefundRoundFundsWithdrawal = true;
      angelFoundationAddress.transfer(this.balance * afterFirstRefundRoundFundsReleaseNumerator / afterFirstRefundRoundFundsReleaseDenominator);
    } else {
      angelFoundationAddress.transfer(this.balance);
    }
  }


  /* Debug. Used by unit tests only */

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
}
