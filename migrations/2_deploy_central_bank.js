const CentralBank = artifacts.require('CentralBank.sol');

module.exports = async (deployer, network, accounts) => {
  await deployer.deploy(CentralBank, { from: accounts[0] });
};
