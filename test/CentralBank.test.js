const AngelToken      = global.artifacts.require('AngelToken.sol');
const CentralBank     = global.artifacts.require('CentralBank.sol');
const CentralBankTest = global.artifacts.require('CentralBankTest.sol');


const verifyContractConfig = async (centralBankInstance, targetFoundationAddress,
                                    targetIcoLaunchTimestamp,
                                    targetIcoDuration,
                                    targetFirstRefundRoundDuration,
                                    targetSecondRefundRoundDuration) => {
  const angelFoundationAddress = await centralBankInstance.angelFoundationAddress.call();
  global.assert.equal(angelFoundationAddress, targetFoundationAddress);

  const icoLaunchTimestamp               = await centralBankInstance.icoLaunchTimestamp.call();
  const icoFinishTimestamp               = await centralBankInstance.icoFinishTimestamp.call();
  const firstRefundRoundFinishTimestamp  = await centralBankInstance.firstRefundRoundFinishTimestamp.call();
  const secondRefundRoundFinishTimestamp = await centralBankInstance.secondRefundRoundFinishTimestamp.call();

  global.assert.equal(icoLaunchTimestamp.toNumber(), targetIcoLaunchTimestamp);
  global.assert.equal(icoFinishTimestamp.toNumber(), targetIcoLaunchTimestamp + targetIcoDuration);
  global.assert.equal(firstRefundRoundFinishTimestamp.toNumber(),
                      targetIcoLaunchTimestamp +
                      targetIcoDuration +
                      targetFirstRefundRoundDuration);
  global.assert.equal(secondRefundRoundFinishTimestamp.toNumber(),
                      targetIcoLaunchTimestamp +
                      targetIcoDuration +
                      targetFirstRefundRoundDuration +
                      targetSecondRefundRoundDuration);
};


global.contract('CentralBank', (accounts) => {
  // config
  const admin      = accounts[0];
  const foundation = accounts[1];
  const investor01 = accounts[2];
  const investor02 = accounts[2];

  const tempIcoDuration               = 10;
  const tempFirstRefundRoundDuration  = 10;
  const tempSecondRefundRoundDuration = 10;

  let centralBankInstance;
  let tempTokenInstance;

  beforeEach(async () => { // eslint-disable-line no-undef
    const tempIcoLaunchTimestamp = Math.round(new Date().getTime() / 1000) - 3;

    centralBankInstance = await CentralBankTest.new({ from: admin });
    await centralBankInstance.setICOConfig.sendTransaction(foundation,
                                                           tempIcoLaunchTimestamp,
                                                           tempIcoDuration,
                                                           tempFirstRefundRoundDuration,
                                                           tempSecondRefundRoundDuration,
                                                           { from: admin });

    const tokenAddress = await centralBankInstance.angelToken.call();
    tempTokenInstance  = await AngelToken.at(tokenAddress); // eslint-disable-line no-multi-spaces

    await verifyContractConfig(centralBankInstance,
                               foundation,
                               tempIcoLaunchTimestamp,
                               tempIcoDuration,
                               tempFirstRefundRoundDuration,
                               tempSecondRefundRoundDuration);

    // global.console.log('Temp CentralBank deployed: ' + centralBankInstance.address);
  });


  /* Test configuration */

  global.it('should test configuration of deployed contract', async () => {
    // global.console.log(new Date().getTime());

    const deployedCentralBankInstance = await CentralBank.deployed();

    await verifyContractConfig(deployedCentralBankInstance,
                               '0xf488ecd0120b75b97378e4941eb6b3c8ec49d748',
                               1504224000,
                               2592000,
                               8640000,
                               8640000);
  });


  /* Test price ladder */

  global.it('should test price ladder', async () => {
    // global.console.log(new Date().getTime());

    let milestonePrice = await centralBankInstance.calculateLandmarkPrice.call(0);
    global.assert.equal(milestonePrice.toNumber(), 1 * (10 ** 14));

    milestonePrice = await centralBankInstance.calculateLandmarkPrice.call(5000 * (10 ** 18));
    global.assert.equal(milestonePrice.toNumber(), 1 * (10 ** 14));

    milestonePrice = await centralBankInstance.calculateLandmarkPrice.call(100000 * (10 ** 18));
    global.assert.equal(milestonePrice.toNumber(), 1 * (10 ** 14));

    milestonePrice = await centralBankInstance.calculateLandmarkPrice.call(1000000 * (10 ** 18));
    global.assert.equal(milestonePrice.toNumber(), 11 * (10 ** 13));

    milestonePrice = await centralBankInstance.calculateLandmarkPrice.call(1999999 * (10 ** 18));
    global.assert.equal(milestonePrice.toNumber(), 11 * (10 ** 13));

    milestonePrice = await centralBankInstance.calculateLandmarkPrice.call(2000000 * (10 ** 18));
    global.assert.equal(milestonePrice.toNumber(), 12 * (10 ** 13));

    milestonePrice = await centralBankInstance.calculateLandmarkPrice.call(9700000 * (10 ** 18));
    global.assert.equal(milestonePrice.toNumber(), 19 * (10 ** 13));

    milestonePrice = await centralBankInstance.calculateLandmarkPrice.call(15000000 * (10 ** 18));
    global.assert.equal(milestonePrice.toNumber(), 25 * (10 ** 13));

    milestonePrice = await centralBankInstance.calculateLandmarkPrice.call(69999999 * (10 ** 18));
    global.assert.equal(milestonePrice.toNumber(), 79 * (10 ** 13));

    // global.console.log(new Date().getTime());
  });

  global.it('should test price ladder for smaller initial price', async () => {
    // global.console.log(new Date().getTime());

    const tempIcoLaunchTimestamp = Math.round(new Date().getTime() / 1000) - 3;

    centralBankInstance = await CentralBankTest.new({ from: admin });
    await centralBankInstance.setTokenPrice.sendTransaction(10 ** 10, { from: admin });
    await centralBankInstance.setICOConfig.sendTransaction(foundation,
                                                           tempIcoLaunchTimestamp,
                                                           tempIcoDuration,
                                                           tempFirstRefundRoundDuration,
                                                           tempSecondRefundRoundDuration,
                                                           { from: admin });

    const tokenAddress = await centralBankInstance.angelToken.call();
    tempTokenInstance  = await AngelToken.at(tokenAddress); // eslint-disable-line no-multi-spaces

    await verifyContractConfig(centralBankInstance,
                               foundation,
                               tempIcoLaunchTimestamp,
                               tempIcoDuration,
                               tempFirstRefundRoundDuration,
                               tempSecondRefundRoundDuration);

    let milestonePrice = await centralBankInstance.calculateLandmarkPrice.call(0);
    global.assert.equal(milestonePrice.toNumber(), 1 * (10 ** 10));

    milestonePrice = await centralBankInstance.calculateLandmarkPrice.call(5000 * (10 ** 18));
    global.assert.equal(milestonePrice.toNumber(), 1 * (10 ** 10));

    milestonePrice = await centralBankInstance.calculateLandmarkPrice.call(100000 * (10 ** 18));
    global.assert.equal(milestonePrice.toNumber(), 1 * (10 ** 10));

    milestonePrice = await centralBankInstance.calculateLandmarkPrice.call(1000000 * (10 ** 18));
    global.assert.equal(milestonePrice.toNumber(), 11 * (10 ** 9));

    milestonePrice = await centralBankInstance.calculateLandmarkPrice.call(1999999 * (10 ** 18));
    global.assert.equal(milestonePrice.toNumber(), 11 * (10 ** 9));

    milestonePrice = await centralBankInstance.calculateLandmarkPrice.call(2000000 * (10 ** 18));
    global.assert.equal(milestonePrice.toNumber(), 12 * (10 ** 9));

    milestonePrice = await centralBankInstance.calculateLandmarkPrice.call(9700000 * (10 ** 18));
    global.assert.equal(milestonePrice.toNumber(), 19 * (10 ** 9));

    milestonePrice = await centralBankInstance.calculateLandmarkPrice.call(15000000 * (10 ** 18));
    global.assert.equal(milestonePrice.toNumber(), 25 * (10 ** 9));

    milestonePrice = await centralBankInstance.calculateLandmarkPrice.call(69999999 * (10 ** 18));
    global.assert.equal(milestonePrice.toNumber(), 79 * (10 ** 9));

    // global.console.log(new Date().getTime());
  });


  /* Test investments */

  global.it('should make simple test for calculation of purchased tokens', async () => {
    // global.console.log(new Date().getTime());

    let purchasedTokens;

    purchasedTokens = await centralBankInstance.calculatePurchasedTokens.call(0, 5 * (10 ** 16));
    global.assert.equal(purchasedTokens[0].toNumber(), 500 * (10 ** 18));
    global.assert.equal(purchasedTokens[1].toNumber(), 0);

    purchasedTokens = await centralBankInstance.calculatePurchasedTokens.call(0, 1 * (10 ** 18));
    global.assert.equal(purchasedTokens[0].toNumber(), 10000 * (10 ** 18));
    global.assert.equal(purchasedTokens[1].toNumber(), 0);

    purchasedTokens = await centralBankInstance.calculatePurchasedTokens.call(0, 10 * (10 ** 18));
    global.assert.equal(purchasedTokens[0].toNumber(), 100000 * (10 ** 18));
    global.assert.equal(purchasedTokens[1].toNumber(), 0);

    purchasedTokens = await centralBankInstance.calculatePurchasedTokens.call(0, 50 * (10 ** 18));
    global.assert.equal(purchasedTokens[0].toNumber(), 500000 * (10 ** 18));
    global.assert.equal(purchasedTokens[1].toNumber(), 0);

    purchasedTokens = await centralBankInstance.calculatePurchasedTokens.call(0, 100 * (10 ** 18));
    global.assert.equal(purchasedTokens[0].toNumber(), 1000000 * (10 ** 18));
    global.assert.equal(purchasedTokens[1].toNumber(), 0);

    purchasedTokens = await centralBankInstance.calculatePurchasedTokens.call(500000 * (10 ** 18), 30 * (10 ** 18));
    global.assert.equal(purchasedTokens[0].toNumber(), 300000 * (10 ** 18));
    global.assert.equal(purchasedTokens[1].toNumber(), 0);

    purchasedTokens = await centralBankInstance.calculatePurchasedTokens.call(0, 155 * (10 ** 18));
    global.assert.equal(purchasedTokens[0].toNumber(), 1500000 * (10 ** 18));
    global.assert.equal(purchasedTokens[1].toNumber(), 0);

    purchasedTokens = await centralBankInstance.calculatePurchasedTokens.call(500000 * (10 ** 18), 105 * (10 ** 18));
    global.assert.equal(purchasedTokens[0].toNumber(), 1000000 * (10 ** 18));
    global.assert.equal(purchasedTokens[1].toNumber(), 0);

    purchasedTokens = await centralBankInstance.calculatePurchasedTokens.call(0, 300 * (10 ** 18));
    global.assert.equal(purchasedTokens[0].toNumber(), 2750000 * (10 ** 18));
    global.assert.equal(purchasedTokens[1].toNumber(), 0);

    purchasedTokens = await centralBankInstance.calculatePurchasedTokens.call(0, 675 * (10 ** 18));
    global.assert.equal(purchasedTokens[0].toNumber(), 5500000 * (10 ** 18));
    global.assert.equal(purchasedTokens[1].toNumber(), 0);

    purchasedTokens = await centralBankInstance.calculatePurchasedTokens.call(500000 * (10 ** 18), 625 * (10 ** 18));
    global.assert.equal(purchasedTokens[0].toNumber(), 5000000 * (10 ** 18));
    global.assert.equal(purchasedTokens[1].toNumber(), 0);

    purchasedTokens = await centralBankInstance.calculatePurchasedTokens.call(1500000 * (10 ** 18), 520 * (10 ** 18));
    global.assert.equal(purchasedTokens[0].toNumber(), 4000000 * (10 ** 18));
    global.assert.equal(purchasedTokens[1].toNumber(), 0);

    purchasedTokens = await centralBankInstance.calculatePurchasedTokens.call(0, 31150 * (10 ** 18));
    global.assert.equal(purchasedTokens[0].toNumber(), 70000000 * (10 ** 18));
    global.assert.equal(purchasedTokens[1].toNumber(), 0);

    // global.console.log(new Date().getTime());
  });

  global.it('should test that calculation of purchased tokens processes investments cap correctly', async () => {
    // global.console.log(new Date().getTime());

    const purchasedTokens = await centralBankInstance.calculatePurchasedTokens.call(69999999 * (10 ** 18), 1 * (10 ** 18));
    global.assert.equal(purchasedTokens[0].toNumber(), 1 * (10 ** 18));
    global.assert.equal(purchasedTokens[1].toNumber(), 999210000000000000);

    // global.console.log(new Date().getTime());
  });

  global.it('should test investments', async () => {
    // global.console.log(new Date().getTime());

    // check initial state
    let investor01Balance = await tempTokenInstance.balanceOf.call(investor01);
    global.assert.equal(investor01Balance.toNumber(), 0);
    let totalSupply = await tempTokenInstance.totalSupply.call();
    global.assert.equal(totalSupply.toNumber(), 0);

    // first investment
    await global.web3.eth.sendTransaction(
      { from: investor01, to: centralBankInstance.address, value: 5 * (10 ** 16), gas: 250000 });
    investor01Balance = await tempTokenInstance.balanceOf.call(investor01);
    global.assert.equal(investor01Balance.toNumber(), 500 * (10 ** 18));
    totalSupply = await tempTokenInstance.totalSupply.call();
    global.assert.closeTo(totalSupply.toNumber(), 714 * (10 ** 18), 1 * (10 ** 18));

    let isValidRecord = await centralBankInstance.validateInvestmentRecord
      .call(investor01, 0, 0, 5 * (10 ** 16), 500 * (10 ** 18), 0, 0);
    global.assert.equal(isValidRecord, true);

    // second investment
    await global.web3.eth.sendTransaction(
      { from: investor01, to: centralBankInstance.address, value: 10 * (10 ** 18), gas: 250000 });
    investor01Balance = await tempTokenInstance.balanceOf.call(investor01);
    global.assert.equal(investor01Balance.toNumber(), 100500 * (10 ** 18));
    totalSupply = await tempTokenInstance.totalSupply.call();
    global.assert.closeTo(totalSupply.toNumber(), 143571 * (10 ** 18), 1 * (10 ** 18));

    isValidRecord = await centralBankInstance.validateInvestmentRecord
      .call(investor01, 0, 0, 5 * (10 ** 16), 500 * (10 ** 18), 0, 0);
    global.assert.equal(isValidRecord, true);
    isValidRecord = await centralBankInstance.validateInvestmentRecord
      .call(investor01, 1, 500 * (10 ** 18), 10 * (10 ** 18), 100000 * (10 ** 18), 0, 0);
    global.assert.equal(isValidRecord, true);

    // global.console.log(new Date().getTime());
  });

  global.it('should test investments cap', async () => {
    // global.console.log(new Date().getTime());

    // check initial state
    let investor01Balance = await tempTokenInstance.balanceOf.call(investor01);
    global.assert.equal(investor01Balance.toNumber(), 0);
    let totalSupply = await tempTokenInstance.totalSupply.call();
    global.assert.equal(totalSupply.toNumber(), 0);

    // first investment
    await global.web3.eth.sendTransaction(
      { from: investor01, to: centralBankInstance.address, value: 31150 * (10 ** 18), gas: 450000 });
    investor01Balance = await tempTokenInstance.balanceOf.call(investor01);
    global.assert.equal(investor01Balance.toNumber(), 70000000 * (10 ** 18));
    totalSupply = await tempTokenInstance.totalSupply.call();
    global.assert.closeTo(totalSupply.toNumber(), 100000000 * (10 ** 18), 1 * (10 ** 18));

    const isValidRecord = await centralBankInstance.validateInvestmentRecord
      .call(investor01, 0, 0, 31150 * (10 ** 18), 70000000 * (10 ** 18), 0, 0);
    global.assert.equal(isValidRecord, true);

    // second investment
    let isCaught = false;
    try {
      await global.web3.eth.sendTransaction(
        { from: investor01, to: centralBankInstance.address, value: 1 * (10 ** 14), gas: 250000 });
    } catch (err) {
      if (err.message.includes('is not a function')) { throw err; }
      isCaught = true;
    }
    global.assert.equal(isCaught, true);

    // global.console.log(new Date().getTime());
  });


  /* Test refunds */

  global.it('should make simple test for calculation of refunded tokens', async () => {
    // global.console.log(new Date().getTime());

    let purchasedTokens;

    purchasedTokens = await centralBankInstance.calculateRefundedEth.call(0, 500 * (10 ** 18));
    global.assert.equal(purchasedTokens[0].toNumber(), 5 * (10 ** 16));
    global.assert.equal(purchasedTokens[1].toNumber(), 0);

    purchasedTokens = await centralBankInstance.calculateRefundedEth.call(500 * (10 ** 18), 500 * (10 ** 18));
    global.assert.equal(purchasedTokens[0].toNumber(), 5 * (10 ** 16));
    global.assert.equal(purchasedTokens[1].toNumber(), 0);

    purchasedTokens = await centralBankInstance.calculateRefundedEth.call(10000 * (10 ** 18), 10000 * (10 ** 18));
    global.assert.equal(purchasedTokens[0].toNumber(), 1 * (10 ** 18));
    global.assert.equal(purchasedTokens[1].toNumber(), 0);

    purchasedTokens = await centralBankInstance.calculateRefundedEth.call(100000 * (10 ** 18), 100000 * (10 ** 18));
    global.assert.equal(purchasedTokens[0].toNumber(), 10 * (10 ** 18));
    global.assert.equal(purchasedTokens[1].toNumber(), 0);

    purchasedTokens = await centralBankInstance.calculateRefundedEth.call(500000 * (10 ** 18), 500000 * (10 ** 18));
    global.assert.equal(purchasedTokens[0].toNumber(), 50 * (10 ** 18));
    global.assert.equal(purchasedTokens[1].toNumber(), 0);

    purchasedTokens = await centralBankInstance.calculateRefundedEth.call(1000000 * (10 ** 18), 1000000 * (10 ** 18));
    global.assert.equal(purchasedTokens[0].toNumber(), 110 * (10 ** 18));
    global.assert.equal(purchasedTokens[1].toNumber(), 0);

    purchasedTokens = await centralBankInstance.calculateRefundedEth.call(800000 * (10 ** 18), 300000 * (10 ** 18));
    global.assert.equal(purchasedTokens[0].toNumber(), 31 * (10 ** 18));
    global.assert.equal(purchasedTokens[1].toNumber(), 0);

    purchasedTokens = await centralBankInstance.calculateRefundedEth.call(1500000 * (10 ** 18), 1500000 * (10 ** 18));
    global.assert.equal(purchasedTokens[0].toNumber(), 175 * (10 ** 18));
    global.assert.equal(purchasedTokens[1].toNumber(), 0);

    purchasedTokens = await centralBankInstance.calculateRefundedEth.call(1500000 * (10 ** 18), 1000000 * (10 ** 18));
    global.assert.equal(purchasedTokens[0].toNumber(), 115 * (10 ** 18));
    global.assert.equal(purchasedTokens[1].toNumber(), 0);

    purchasedTokens = await centralBankInstance.calculateRefundedEth.call(2750000 * (10 ** 18), 2750000 * (10 ** 18));
    global.assert.equal(purchasedTokens[0].toNumber(), 375 * (10 ** 18));
    global.assert.equal(purchasedTokens[1].toNumber(), 0);

    purchasedTokens = await centralBankInstance.calculateRefundedEth.call(5500000 * (10 ** 18), 5500000 * (10 ** 18));
    global.assert.equal(purchasedTokens[0].toNumber(), 975 * (10 ** 18));
    global.assert.equal(purchasedTokens[1].toNumber(), 0);

    purchasedTokens = await centralBankInstance.calculateRefundedEth.call(5500000 * (10 ** 18), 5000000 * (10 ** 18));
    global.assert.equal(purchasedTokens[0].toNumber(), 875 * (10 ** 18));
    global.assert.equal(purchasedTokens[1].toNumber(), 0);

    purchasedTokens = await centralBankInstance.calculateRefundedEth.call(69000000 * (10 ** 18), 1000001 * (10 ** 18));
    global.assert.equal(purchasedTokens[0].toNumber(), 790 * (10 ** 18));
    global.assert.equal(purchasedTokens[1].toNumber(), 1 * (10 ** 18));

    // global.console.log(new Date().getTime());
  });

  global.it('should test refunds', async () => {
    // global.console.log(new Date().getTime());

    // check initial state
    const investor02ETHBalance = await global.web3.eth.getBalance(investor02);
    global.assert.isAbove(investor02ETHBalance.toNumber(), 205 * (10 ** 18));
    let investor02Balance = await tempTokenInstance.balanceOf.call(investor02);
    global.assert.equal(investor02Balance.toNumber(), 0);
    let totalSupply = await tempTokenInstance.totalSupply.call();
    global.assert.equal(totalSupply.toNumber(), 0);

    // first investment
    await global.web3.eth.sendTransaction(
      { from: investor02, to: centralBankInstance.address, value: 10 * (10 ** 18), gas: 250000 });
    investor02Balance = await tempTokenInstance.balanceOf.call(investor02);
    global.assert.equal(investor02Balance.toNumber(), 100000 * (10 ** 18));
    totalSupply = await tempTokenInstance.totalSupply.call();
    global.assert.closeTo(totalSupply.toNumber(), 142857 * (10 ** 18), 1 * (10 ** 18));

    let isValidRecord = await centralBankInstance.validateInvestmentRecord
      .call(investor02, 0, 0, 10 * (10 ** 18), 100000 * (10 ** 18), 0, 0);
    global.assert.equal(isValidRecord, true);

    // second investment
    await global.web3.eth.sendTransaction(
      { from: investor02, to: centralBankInstance.address, value: 200 * (10 ** 18), gas: 250000 });
    investor02Balance = await tempTokenInstance.balanceOf.call(investor02);
    global.assert.equal(investor02Balance.toNumber(), 2000000 * (10 ** 18));
    totalSupply = await tempTokenInstance.totalSupply.call();
    global.assert.closeTo(totalSupply.toNumber(), 2857142 * (10 ** 18), 1 * (10 ** 18));

    isValidRecord = await centralBankInstance.validateInvestmentRecord
      .call(investor02, 0, 0, 10 * (10 ** 18), 100000 * (10 ** 18), 0, 0);
    global.assert.equal(isValidRecord, true);
    isValidRecord = await centralBankInstance.validateInvestmentRecord
      .call(investor02, 1, 100000 * (10 ** 18), 200 * (10 ** 18), 1900000 * (10 ** 18), 0, 0);
    global.assert.equal(isValidRecord, true);

    // first refund
    let investorBalanceBefore = await global.web3.eth.getBalance(investor02);
    await tempTokenInstance.transfer.sendTransaction(centralBankInstance.address, 200000 * (10 ** 18),
                                                     { from: investor02 });
    investor02Balance = await tempTokenInstance.balanceOf.call(investor02);
    global.assert.equal(investor02Balance.toNumber(), 1800000 * (10 ** 18));
    totalSupply = await tempTokenInstance.totalSupply.call();
    global.assert.closeTo(totalSupply.toNumber(), 2657142 * (10 ** 18), 1 * (10 ** 18));
    let investorBalanceAfter = await global.web3.eth.getBalance(investor02);
    global.assert.isAbove(investorBalanceAfter - investorBalanceBefore, 159 * (10 ** 17));  // because of TX fee
    global.assert.isBelow(investorBalanceAfter - investorBalanceBefore, 160 * (10 ** 17));

    isValidRecord = await centralBankInstance.validateInvestmentRecord
      .call(investor02, 0, 0, 10 * (10 ** 18), 100000 * (10 ** 18),
            10 * (10 ** 18), 100000 * (10 ** 18));
    global.assert.equal(isValidRecord, true);
    isValidRecord = await centralBankInstance.validateInvestmentRecord
      .call(investor02, 1, 100000 * (10 ** 18), 200 * (10 ** 18), 1900000 * (10 ** 18),
            10 * (10 ** 18), 100000 * (10 ** 18));
    global.assert.equal(isValidRecord, true);

    // sleep
    await new Promise((resolve) => setTimeout(resolve, tempIcoDuration * 1000));

    // second refund
    investorBalanceBefore = await global.web3.eth.getBalance(investor02);
    await tempTokenInstance.transfer.sendTransaction(centralBankInstance.address, 1700000 * (10 ** 18),
                                                     { from: investor02 });
    investor02Balance = await tempTokenInstance.balanceOf.call(investor02);
    global.assert.equal(investor02Balance.toNumber(), 100000 * (10 ** 18));
    totalSupply = await tempTokenInstance.totalSupply.call();
    global.assert.closeTo(totalSupply.toNumber(), 957142 * (10 ** 18), 1 * (10 ** 18));
    investorBalanceAfter = await global.web3.eth.getBalance(investor02);
    global.assert.isAbove(investorBalanceAfter - investorBalanceBefore, 1431 * (10 ** 17));  // because of TX fee
    global.assert.isBelow(investorBalanceAfter - investorBalanceBefore, 1432 * (10 ** 17));

    isValidRecord = await centralBankInstance.validateInvestmentRecord
      .call(investor02, 0, 0, 10 * (10 ** 18), 100000 * (10 ** 18),
            10 * (10 ** 18), 100000 * (10 ** 18));
    global.assert.equal(isValidRecord, true);
    isValidRecord = await centralBankInstance.validateInvestmentRecord
      .call(investor02, 1, 100000 * (10 ** 18), 200 * (10 ** 18), 1900000 * (10 ** 18),
            189 * (10 ** 18), 1800000 * (10 ** 18));
    global.assert.equal(isValidRecord, true);

    // sleep
    await new Promise((resolve) => setTimeout(resolve, tempFirstRefundRoundDuration * 1000));

    // third refund
    investorBalanceBefore = await global.web3.eth.getBalance(investor02);
    await tempTokenInstance.transfer.sendTransaction(centralBankInstance.address, 100000 * (10 ** 18),
                                                     { from: investor02 });
    investor02Balance = await tempTokenInstance.balanceOf.call(investor02);
    global.assert.equal(investor02Balance.toNumber(), 0);
    totalSupply = await tempTokenInstance.totalSupply.call();
    global.assert.closeTo(totalSupply.toNumber(), 857142 * (10 ** 18), 1 * (10 ** 18));
    investorBalanceAfter = await global.web3.eth.getBalance(investor02);
    global.assert.isAbove(investorBalanceAfter - investorBalanceBefore, 439 * (10 ** 16));  // because of TX fee
    global.assert.isBelow(investorBalanceAfter - investorBalanceBefore, 440 * (10 ** 16));

    isValidRecord = await centralBankInstance.validateInvestmentRecord
      .call(investor02, 0, 0, 10 * (10 ** 18), 100000 * (10 ** 18),
            10 * (10 ** 18), 100000 * (10 ** 18));
    global.assert.equal(isValidRecord, true);
    isValidRecord = await centralBankInstance.validateInvestmentRecord
      .call(investor02, 1, 100000 * (10 ** 18), 200 * (10 ** 18), 1900000 * (10 ** 18),
            200 * (10 ** 18), 1900000 * (10 ** 18));
    global.assert.equal(isValidRecord, true);

    // global.console.log(new Date().getTime());
  });


  /* Lifecycle */

  global.it('should test unpausing of angel token', async () => {
    // global.console.log(new Date().getTime());

    // check initial state
    const investor01ETHBalance = await global.web3.eth.getBalance(investor01);
    global.assert.isAbove(investor01ETHBalance.toNumber(), 15 * (10 ** 18));
    let investor01Balance = await tempTokenInstance.balanceOf.call(investor01);
    global.assert.equal(investor01Balance.toNumber(), 0);
    let totalSupply = await tempTokenInstance.totalSupply.call();
    global.assert.equal(totalSupply.toNumber(), 0);
    let isPaused = await tempTokenInstance.getPaused.call();
    global.assert.equal(isPaused, true);

    // first investment
    await global.web3.eth.sendTransaction(
      { from: investor01, to: centralBankInstance.address, value: 7 * (10 ** 16), gas: 250000 });
    investor01Balance = await tempTokenInstance.balanceOf.call(investor01);
    global.assert.equal(investor01Balance.toNumber(), 700 * (10 ** 18));
    totalSupply = await tempTokenInstance.totalSupply.call();
    global.assert.closeTo(totalSupply.toNumber(), 1000 * (10 ** 18), 1 * (10 ** 18));

    const isValidRecord = await centralBankInstance.validateInvestmentRecord
      .call(investor01, 0, 0, 7 * (10 ** 16), 700 * (10 ** 18), 0, 0);
    global.assert.equal(isValidRecord, true);

    // sleep
    await new Promise((resolve) => setTimeout(resolve, tempIcoDuration * 1000));

    // unpause token
    await centralBankInstance.unpauseAngelToken.sendTransaction();

    // test angel token
    const foundationBalance = await tempTokenInstance.balanceOf.call(foundation);
    global.assert.equal(foundationBalance.toNumber(), 300 * (10 ** 18));
    isPaused = await tempTokenInstance.getPaused.call();
    global.assert.equal(isPaused, false);
  });

  global.it('should test withdrawing of funds', async () => {
    // global.console.log(new Date().getTime());

    // check initial state
    const investor01Balance = await tempTokenInstance.balanceOf.call(investor01);
    global.assert.equal(investor01Balance.toNumber(), 0);
    const totalSupply = await tempTokenInstance.totalSupply.call();
    global.assert.equal(totalSupply.toNumber(), 0);

    const foundationInitialBalance = global.web3.eth.getBalance(foundation);

    // first investment
    await global.web3.eth.sendTransaction(
      { from: investor01, to: centralBankInstance.address, value: 5 * (10 ** 16), gas: 250000 });
    let foundationBalance = global.web3.eth.getBalance(foundation);
    global.assert.equal(foundationBalance.toNumber(), foundationInitialBalance.toNumber() + (1 * (10 ** 16)));

    // second investment
    await global.web3.eth.sendTransaction(
      { from: investor01, to: centralBankInstance.address, value: 10 * (10 ** 18), gas: 250000 });
    foundationBalance = global.web3.eth.getBalance(foundation);
    global.assert.closeTo(foundationBalance.toNumber(),
                          foundationInitialBalance.toNumber() + (201 * (10 ** 16)),
                          1 * (10 ** 14));

    // sleep
    await new Promise((resolve) => setTimeout(resolve, tempFirstRefundRoundDuration * 1000));

    // withdraw 40%
    await centralBankInstance.withdrawFoundationFunds({ from: admin });
    foundationBalance = global.web3.eth.getBalance(foundation);
    global.assert.closeTo(foundationBalance.toNumber(),
                          ((foundationInitialBalance.toNumber() / (10 ** 16)) + 603) * (10 ** 16),
                          1 * (10 ** 14));

    // sleep
    await new Promise((resolve) => setTimeout(resolve, tempSecondRefundRoundDuration * 1000));

    // withdraw remaining
    await centralBankInstance.withdrawFoundationFunds({ from: admin });
    foundationBalance = global.web3.eth.getBalance(foundation);
    global.assert.closeTo(foundationBalance.toNumber(),
                          foundationInitialBalance.toNumber() + (1005 * (10 ** 16)),
                          1 * (10 ** 14));

    // global.console.log(new Date().getTime());
  });
});
