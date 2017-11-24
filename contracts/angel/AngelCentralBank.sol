pragma solidity ^0.4.15;


import '../zeppelin-solidity/SafeMath.sol';
import './AngelToken.sol';


/**
 * @title AngelCentralBank
 *
 * @dev Crowdsale and escrow contract
 */
contract AngelCentralBank {

  /* Data structures */

  struct InvestmentRecord {
    uint tokensSoldBeforeWei;
    uint investedEthWei;
    uint purchasedTokensWei;
    uint refundedEthWei;
    uint returnedTokensWei;
  }


  /* Storage - config */

  uint public constant icoCap = 70000000 * (10 ** 18);

  uint public initialTokenPrice = 1 * (10 ** 18) / (10 ** 4); // means 0.0001 ETH for one token

  uint public constant landmarkSize = 1000000 * (10 ** 18);
  uint public constant landmarkPriceStepNumerator = 10;
  uint public constant landmarkPriceStepDenominator = 100;

  uint public constant firstRefundRoundRateNumerator = 80;
  uint public constant firstRefundRoundRateDenominator = 100;
  uint public constant secondRefundRoundRateNumerator = 40;
  uint public constant secondRefundRoundRateDenominator = 100;

  uint public constant initialFundsReleaseNumerator = 20; // part of investment
  uint public constant initialFundsReleaseDenominator = 100;
  uint public constant afterFirstRefundRoundFundsReleaseNumerator = 50; // part of remaining funds
  uint public constant afterFirstRefundRoundFundsReleaseDenominator = 100;

  uint public constant angelFoundationShareNumerator = 30;
  uint public constant angelFoundationShareDenominator = 100;

  /* Storage - state */

  address public angelFoundationAddress = address(0x2b0556a6298eA3D35E90F1df32cc126b31F59770);
  uint public icoLaunchTimestamp = 1511784000;  // November 27th 12:00 GMT
  uint public icoFinishTimestamp = 1514376000;  // December 27th 12:00 GMT
  uint public firstRefundRoundFinishTimestamp = 1520424000;  // March 7th 2018 12:00 GMT
  uint public secondRefundRoundFinishTimestamp = 1524744000;  // April 26th 2018 12:00 GMT


  AngelToken public angelToken;

  mapping (address => InvestmentRecord[]) public investments; // investorAddress => list of investments
  mapping (address => bool) public investors;
  uint public totalInvestors = 0;
  uint public totalTokensSold = 0;

  bool isIcoFinished = false;
  bool firstRefundRoundFundsWithdrawal = false;


  /* Events */

  event InvestmentEvent(address indexed investor, uint eth, uint angel);
  event RefundEvent(address indexed investor, uint eth, uint angel);


  /* Constructor and config */

  function AngelCentralBank() public {
    angelToken = new AngelToken();
    angelToken.enableManager(address(this));
    angelToken.grantManagerPermission(address(this), 'mint_tokens');
    angelToken.grantManagerPermission(address(this), 'burn_tokens');
    angelToken.grantManagerPermission(address(this), 'unpause_contract');
    angelToken.transferOwnership(angelFoundationAddress);
  }

  /* Investments */

  /**
   * @dev Fallback function receives ETH and sends tokens back
   */
  function () public payable {
    angelRaise();
  }

  /**
   * @dev Process new ETH investment and sends tokens back
   */
  function angelRaise() internal {
    require(msg.value > 0);
    require(now >= icoLaunchTimestamp && now < icoFinishTimestamp);

    // calculate amount of tokens for received ETH
    uint _purchasedTokensWei = 0;
    uint _notProcessedEthWei = 0;
    (_purchasedTokensWei, _notProcessedEthWei) = calculatePurchasedTokens(totalTokensSold, msg.value);
    uint _actualInvestment = (msg.value - _notProcessedEthWei);

    // create record for the investment
    uint _newRecordIndex = investments[msg.sender].length;
    investments[msg.sender].length += 1;
    investments[msg.sender][_newRecordIndex].tokensSoldBeforeWei = totalTokensSold;
    investments[msg.sender][_newRecordIndex].investedEthWei = _actualInvestment;
    investments[msg.sender][_newRecordIndex].purchasedTokensWei = _purchasedTokensWei;
    investments[msg.sender][_newRecordIndex].refundedEthWei = 0;
    investments[msg.sender][_newRecordIndex].returnedTokensWei = 0;

    // calculate stats
    if (investors[msg.sender] == false) {
      totalInvestors += 1;
    }
    investors[msg.sender] = true;
    totalTokensSold += _purchasedTokensWei;

    // transfer tokens and ETH
    angelToken.mint(msg.sender, _purchasedTokensWei);
    angelToken.mint(angelFoundationAddress,
                    _purchasedTokensWei * angelFoundationShareNumerator / (angelFoundationShareDenominator - angelFoundationShareNumerator));
    angelFoundationAddress.transfer(_actualInvestment * initialFundsReleaseNumerator / initialFundsReleaseDenominator);
    if (_notProcessedEthWei > 0) {
      msg.sender.transfer(_notProcessedEthWei);
    }

    // finish ICO if cap reached
    if (totalTokensSold >= icoCap) {
      icoFinishTimestamp = now;

      finishIco();
    }

    // fire event
    InvestmentEvent(msg.sender, _actualInvestment, _purchasedTokensWei);
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
    constant public returns (uint _purchasedTokensWei, uint _notProcessedEthWei)
  {
    _purchasedTokensWei = 0;
    _notProcessedEthWei = _investedEthWei;

    uint _landmarkPrice;
    uint _maxLandmarkTokensWei;
    uint _maxLandmarkEthWei;
    bool _isCapReached = false;
    do {
      // get landmark values
      _landmarkPrice = calculateLandmarkPrice(_totalTokensSoldBefore + _purchasedTokensWei);
      _maxLandmarkTokensWei = landmarkSize - ((_totalTokensSoldBefore + _purchasedTokensWei) % landmarkSize);
      if (_totalTokensSoldBefore + _purchasedTokensWei + _maxLandmarkTokensWei >= icoCap) {
        _maxLandmarkTokensWei = icoCap - _totalTokensSoldBefore - _purchasedTokensWei;
        _isCapReached = true;
      }
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
    while ((_notProcessedEthWei > 0) && (_isCapReached == false));

    assert(_purchasedTokensWei > 0);

    return (_purchasedTokensWei, _notProcessedEthWei);
  }


  /* Refunds */

  function angelBurn(
    address _investor,
    uint _returnedTokensWei
  )
    external returns (uint)
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
    uint _recordNotProcessedTokensWei = 0;
    for (uint _recordID = 0; _recordID < _allRecordsNumber; _recordID += 1) {
      if (investments[_investor][_recordID].purchasedTokensWei <= investments[_investor][_recordID].returnedTokensWei ||
          investments[_investor][_recordID].investedEthWei <= investments[_investor][_recordID].refundedEthWei) {
        // tokens already refunded
        continue;
      }

      // calculate amount of tokens to refund with this record
      _recordMaxReturnedTokensWei = investments[_investor][_recordID].purchasedTokensWei -
                                    investments[_investor][_recordID].returnedTokensWei;
      _recordTokensWeiToProcess = (_notProcessedTokensWei < _recordMaxReturnedTokensWei) ? _notProcessedTokensWei :
                                                                                           _recordMaxReturnedTokensWei;
      assert(_recordTokensWeiToProcess > 0);

      // calculate amount of ETH to send back
      _tokensSoldWei = investments[_investor][_recordID].tokensSoldBeforeWei + investments[_investor][_recordID].returnedTokensWei;
      (_recordRefundedEthWei, _recordNotProcessedTokensWei) = calculateRefundedEth(_tokensSoldWei, _recordTokensWeiToProcess);
      if (_recordRefundedEthWei > (investments[_investor][_recordID].investedEthWei - investments[_investor][_recordID].refundedEthWei)) {
        // this can happen due to rounding error
        _recordRefundedEthWei = (investments[_investor][_recordID].investedEthWei - investments[_investor][_recordID].refundedEthWei);
      }
      assert(_recordRefundedEthWei > 0);
      assert(_recordNotProcessedTokensWei == 0);

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
    angelToken.burn(_returnedTokensWei - _notProcessedTokensWei);
    if (_notProcessedTokensWei > 0) {
      angelToken.transfer(_investor, _notProcessedTokensWei);
    }
    _investor.transfer(_refundedEthWeiWithDiscount);

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
    public constant returns (uint)
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
   * @param _totalTokensSoldBefore     uint Amount of tokens that have been sold (starting point) [token wei]
   * @param _returnedTokensWei uint Amount of tokens to refund [token wei]
   * @return Refunded amount of ETH [ETH wei] (without discounts)
   */
  function calculateRefundedEth(
    uint _totalTokensSoldBefore,
    uint _returnedTokensWei
  )
    public constant returns (uint _refundedEthWei, uint _notProcessedTokensWei)
  {
    _refundedEthWei = 0;
    uint _refundedTokensWei = 0;
    _notProcessedTokensWei = _returnedTokensWei;

    uint _landmarkPrice = 0;
    uint _maxLandmarkTokensWei = 0;
    uint _maxLandmarkEthWei = 0;
    bool _isCapReached = false;
    do {
      // get landmark values
      _landmarkPrice = calculateLandmarkPrice(_totalTokensSoldBefore + _refundedTokensWei);
      _maxLandmarkTokensWei = landmarkSize - ((_totalTokensSoldBefore + _refundedTokensWei) % landmarkSize);
      if (_totalTokensSoldBefore + _refundedTokensWei + _maxLandmarkTokensWei >= icoCap) {
        _maxLandmarkTokensWei = icoCap - _totalTokensSoldBefore - _refundedTokensWei;
        _isCapReached = true;
      }
      _maxLandmarkEthWei = _maxLandmarkTokensWei * _landmarkPrice / (10 ** 18);

      // check investment against landmark values
      if (_notProcessedTokensWei > _maxLandmarkTokensWei) {
        _refundedEthWei += _maxLandmarkEthWei;
        _refundedTokensWei += _maxLandmarkTokensWei;
        _notProcessedTokensWei -= _maxLandmarkTokensWei;
      }
      else {
        _refundedEthWei += _notProcessedTokensWei * _landmarkPrice / (10 ** 18);
        _refundedTokensWei += _notProcessedTokensWei;
        _notProcessedTokensWei = 0;
      }
    }
    while ((_notProcessedTokensWei > 0) && (_isCapReached == false));

    assert(_refundedEthWei > 0);

    return (_refundedEthWei, _notProcessedTokensWei);
  }


  /* Calculation of the price */

  /**
   * @dev Calculate price for tokens
   * @param _totalTokensSoldBefore uint Amount of tokens sold before [token wei]
   * @return Calculated price
   */
  function calculateLandmarkPrice(uint _totalTokensSoldBefore) public constant returns (uint) {
    return initialTokenPrice + initialTokenPrice
                               * landmarkPriceStepNumerator / landmarkPriceStepDenominator
                               * (_totalTokensSoldBefore / landmarkSize);
  }


  /* Lifecycle */

  function finishIco() public {
    require(now >= icoFinishTimestamp);
    require(isIcoFinished == false);

    isIcoFinished = true;

    angelToken.unpauseContract();
  }

  function withdrawFoundationFunds() external {
    require(now > firstRefundRoundFinishTimestamp);

    if (now > firstRefundRoundFinishTimestamp && now <= secondRefundRoundFinishTimestamp) {
      require(firstRefundRoundFundsWithdrawal == false);

      firstRefundRoundFundsWithdrawal = true;
      angelFoundationAddress.transfer(this.balance * afterFirstRefundRoundFundsReleaseNumerator / afterFirstRefundRoundFundsReleaseDenominator);
    } else {
      angelFoundationAddress.transfer(this.balance);
    }
  }
}
