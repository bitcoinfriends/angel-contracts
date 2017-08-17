const AngelToken = global.artifacts.require('AngelToken.sol');
const CentralBank = global.artifacts.require('CentralBank.sol');


global.contract('AngelToken', () => {
  global.it('should check initial minting of the token', async () => {
    const centralBankInstance = await CentralBank.deployed();
    const tokenAddress = await centralBankInstance.angelToken.call();
    const tokenInstance = await AngelToken.at(tokenAddress);

    const totalSupply = await tokenInstance.totalSupply.call();
    global.assert.equal(totalSupply, 0);
  });

  global.it('should check name, symbol, decimals, owner of the token', async () => {
    const centralBankInstance = await CentralBank.deployed();
    const tokenAddress = await centralBankInstance.angelToken.call();
    const tokenInstance = await AngelToken.at(tokenAddress);

    const name = await tokenInstance.name.call();
    global.assert.equal(name, 'Angel Token');

    const symbol = await tokenInstance.symbol.call();
    global.assert.equal(symbol, 'ANGEL');

    const decimals = await tokenInstance.decimals.call();
    global.assert.equal(decimals, 18);

    const owner = await tokenInstance.owner.call();
    global.assert.equal(owner, '0xF488ecd0120B75b97378e4941Eb6B3c8ec49d748'.toLowerCase());
  });

  global.it('should check that token is paused', async () => {
    const centralBankInstance = await CentralBank.deployed();
    const tokenAddress = await centralBankInstance.angelToken.call();
    const tokenInstance = await AngelToken.at(tokenAddress);

    const paused = await tokenInstance.getPaused.call();
    global.assert.equal(paused, true);
  });
});
