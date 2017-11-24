const AngelToken = global.artifacts.require('AngelToken.sol');
const CentralBank = global.artifacts.require('AngelCentralBank.sol');


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
    global.assert.equal(symbol, 'ANGL');

    const decimals = await tokenInstance.decimals.call();
    global.assert.equal(decimals, 18);

    const owner = await tokenInstance.owner.call();
    global.assert.equal(owner, '0x2b0556a6298eA3D35E90F1df32cc126b31F59770'.toLowerCase());
  });

  global.it('should check that token is paused', async () => {
    const centralBankInstance = await CentralBank.deployed();
    const tokenAddress = await centralBankInstance.angelToken.call();
    const tokenInstance = await AngelToken.at(tokenAddress);

    const paused = await tokenInstance.getPaused.call();
    global.assert.equal(paused, true);
  });
});
