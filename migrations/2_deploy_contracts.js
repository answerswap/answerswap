const Factory = artifacts.require('uniswapv2/UniswapV2Factory.sol'); // failed 
const Router = artifacts.require('uniswapv2/UniswapV2Router02.sol'); // failed
const WETH = artifacts.require('WETH.sol');
const MockERC20 = artifacts.require('MockERC20.sol');

// AnswerToken 
const PowerToken = artifacts.require('PowerToken.sol'); 
const PowerMasterChef = artifacts.require('PowerMasterChef.sol');  // 

// const AnswerToken = artifacts.require('AnswerToken.sol') ; //failed
// const MasterChef = artifacts.require('MasterChef.sol');  // 
const AnswerBar = artifacts.require('AnswerBar.sol'); // 
const AnswerMaker = artifacts.require('AnswerMaker.sol'); //
const Migrator = artifacts.require('Migrator.sol');

//truffle deploy --network mainnet

module.exports = async function(deployer, _network, addresses) {
  const [admin, _] = addresses;

// for Uniswap deploy
// const weth_address = '0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2';

 await deployer.deploy(WETH); 
 const weth = await WETH.deployed();
 const tokenA = await MockERC20.new('Token A', 'TKA', web3.utils.toWei('1000')); 
 const tokenB = await MockERC20.new('Token B', 'TKB', web3.utils.toWei('1000'));

 // 1) UniswapV2Factory 
  // const uniswapv2factory_adddress = "0x0FB7E9A1226c5fb66D4580eb6E71fb8d3532EDf3";
  await deployer.deploy(Factory, admin);
  const factory = await Factory.deployed();

  await factory.createPair(weth.address, tokenA.address); // WETH - Token A Pair 
  await factory.createPair(weth.address, tokenB.address); // WETH - Token B Pair

  // 2) UniswapV2Router02  
  const uniswapv2router02_address = "0xBc5fC20fc1a2E766D637A4a5BfD83aeB89367df1";
  await deployer.deploy(Router, factory.address, weth.address); 
  const router = await Router.deployed();

  
  // const uniswap_v2_factory_address = '0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f' 
  // 버그 날때의 구성 = v1 "0xC0AEe478e3658e2610c5F7A4A2E1777cE9e4f2Ac";  => UniswapV2Factory of SushiSwap 
  //0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f = UniswapV2Factory

  await deployer.deploy(PowerToken,1,1000);
  const powerToken = await PowerToken.deployed();

// for AnswerToken deploy 
  //await deployer.deploy(AnswerToken);
  // const answerToken = await AnswerToken.deployed();
  //const answertoken_address = "0x3bef8b5c2280b7fc065b7d99b60d6e6a76679ac8";


  await deployer.deploy(
    PowerMasterChef,
    powerToken.address,//answertoken_address,// 
    admin, // 지정된게 맞는가?
    web3.utils.toWei('100'), // How many Block will created  
    1, // start block 
    1000000 // end block of Bonus period 100,000 Block = 2 Weeks
  );
  

  // await answerToken.transferOwnership(masterChef.address); TODO : 수동으로 수행할것 

  //await deployer.deploy(AnswerBar, answerToken.address); // Bar = for Stake answertoken_address );//
  // const answerBar = await AnswerBar.deployed();


  // await deployer.deploy(
  //   AnswerMaker,
  //   factory.address, //uniswap_v2_factory_address,//uniswapv2factory_adddress, // 
  //   answerBar.address, //answerBar_address, //
  //   answerToken.address, //answerToken_address,//answertoken_address,// 
  //   weth_address// weth.address//
  // );
  // const answerMaker = await AnswerMaker.deployed(); 

//await factory.setFeeTo(answerMaker.address); // TODO : 수동으로 수행할것  VM Exception while processing transaction: revert UniswapV2: FORBIDDEN => 직접 인터랙션해서 해결 (!)

// Liquidity Migration 

  // await deployer.deploy(
  //   Migrator,
  //   masterChef.address,
  //   '0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f', //address of Uniswapv2 Factory 이게 유니스왑것 
  //   factory.address, // answer swap factory address
  //   1 
  // );
};
