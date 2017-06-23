const CentralBank = artifacts.require('CentralBank.sol');


const angelFoundationAddress    = '0x123';  // todo set correct address
const icoLaunchTimestamp        = 1504224000;
const icoDuration               = 2592000;
const firstRefundRoundDuration  = 8640000;
const secondRefundRoundDuration = 8640000;


module.exports = async (deployer, network, accounts) => {
  await deployer.deploy(CentralBank, { from: accounts[0] });
  const centralBankInstance = await CentralBank.deployed();

  await centralBankInstance.setICOConfig.sendTransaction(angelFoundationAddress,
                                                         icoLaunchTimestamp,
                                                         icoDuration,
                                                         firstRefundRoundDuration,
                                                         secondRefundRoundDuration,
                                                         { from: accounts[0] });
};
