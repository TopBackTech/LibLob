var BoomrCoinCrowdsale = artifacts.require("./BoomrCoinCrowdsale.sol")
var BoomrCoin = artifacts.require("./BoomrCoin.sol")

module.exports = function(deployer, network, accounts) {

	var moment = require('moment');

	const pstartTime = moment().utc().unix() + 30;
	const wallet = accounts[0];

	console.log("Wallet = " + wallet);
	console.log("StartTime = " + pstartTime);
 
	var coinInstance;
	var csaleInstance;

	deployer.deploy(BoomrCoin).then(function() {

		return BoomrCoin.deployed().then(function(instance) {
		coinInstance = instance;
		console.log("Coin address = " + instance.address);		  		
  		return deployer.deploy(BoomrCoinCrowdsale);		
		}).then(function() {
		return coinInstance.balanceOf.call(accounts[0]);
		}).then(function(result) {
			console.log("Balance = " + result);
			return BoomrCoinCrowdsale.deployed();
		}).then(function(instancei) {
			csaleInstance = instancei;
			return csaleInstance.StartCrowdsale(coinInstance.address, wallet, pstartTime, {from: accounts[0]});
		}).then(function(result) {
			return coinInstance.transfer(csaleInstance.address, web3.toWei(150000000, "ether"), {from: accounts[0]});
		}).then(function(result) {
			//console.log("Result = " + result);
		})
	});
}