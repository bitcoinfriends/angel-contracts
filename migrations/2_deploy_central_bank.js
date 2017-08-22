const CentralBank = artifacts.require('AngelCentralBank.sol');

module.exports = async (deployer, network, accounts) => {
  await deployer.deploy(CentralBank, { from: accounts[0] });
};
