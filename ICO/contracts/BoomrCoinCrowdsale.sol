pragma solidity ^0.4.11;

import 'zeppelin-solidity/contracts/ownership/Ownable.sol';
import 'zeppelin-solidity/contracts/math/SafeMath.sol';
import 'zeppelin-solidity/contracts/crowdsale/RefundVault.sol';
import './BoomrCoin.sol';

//*****************************************************
// *   BoomrCoinCrowdsale
// *   Info:
//     - Sale will be for 30% (150M of 500) of total tokens
//     - Funding during presale determines price
//     - Times are in UTC (seconds since Jan 1 1970)
//   
//*****************************************************
contract BoomrCoinCrowdsale is Ownable{
  using SafeMath for uint256;

  //***************************************************
  //  Settings
  //*************************************************** 

  // minimum amount of funds to be raised in weis
  uint256 private minGoal = 0;

  // Tokens for presale
  uint256 private tokenLimitPresale    =  0;
  
  // Tokens for crowdsale 
  uint256 private tokenLimitCrowdsale  = 0;
  
  // Presale discount for each phase
  uint256 private presaleDiscount    = 0;
  uint256 private crowdsaleDiscount1 = 0;
  uint256 private crowdsaleDiscount2 = 0;
  uint256 private crowdsaleDiscount3 = 0;
  uint256 private crowdsaleDiscount4 = 0;

  // durations for each phase
  uint256 private  presaleDuration    = 0;//604800; // One Week in seconds
  uint256 private  crowdsaleDuration1 = 0;//604800; // One Week in seconds
  uint256 private  crowdsaleDuration2 = 0;//604800; // One Week in seconds
  uint256 private  crowdsaleDuration3 = 0;//604800; // One Week in seconds
  uint256 private  crowdsaleDuration4 = 0;//604800; // One Week in seconds

  //***************************************************
  //  Info
  //*************************************************** 

  // Tokens Sold
  uint256 private tokenPresaleTotalSold  = 0;
  uint256 private tokenCrowdsaleTotalSold  = 0;

  // Backers
  uint256 private totalBackers  = 0;

  // amount of raised money in wei
  uint256 private weiRaised = 0;

  // prices for each phase
  uint256 private presaleTokenPrice    = 0;
  uint256 private baseTokenPrice = 0;
  uint256 private crowdsaleTokenPrice1 = 0;
  uint256 private crowdsaleTokenPrice2 = 0;
  uint256 private crowdsaleTokenPrice3 = 0;
  uint256 private crowdsaleTokenPrice4 = 0;

  // Count of token distributions by phase
  uint256 private presaleTokenSent     = 0;  
  uint256 private crowdsaleTokenSold1  = 0;
  uint256 private crowdsaleTokenSold2  = 0;
  uint256 private crowdsaleTokenSold3  = 0;
  uint256 private crowdsaleTokenSold4  = 0;

  //***************************************************
  //  Vars
  //*************************************************** 

  // Finalization Flag
  bool private finalized = false;

  // Halted Flag
  bool private halted = false;

  uint256 public startTime;

  // The token being sold 
  BoomrCoin public boomrToken;

  // Address where funds are collected
  address private wallet;

  // refund vault used to hold funds while crowdsale is running
  RefundVault private vault;

  // tracking for deposits 
  mapping (address => uint256) public deposits;

  // tracking for purchasers
  mapping (address => uint256) public purchases;

  //***************************************************
  //  Events
  //*************************************************** 

  // Log event for crowdsale purchase
  event TokenPurchase(address indexed Purchaser, address indexed Beneficiary, uint256 ValueInWei, uint256 TokenAmount);

  // Log event for presale purchase
  event PresalePurchase(address indexed Purchaser, address indexed Beneficiary, uint256 ValueInWei);

  // Log event for distribution of tokens for presale purchasers
  event PresaleDistribution(address indexed Purchaser, address indexed Beneficiary, uint256 TokenAmount);

  // Finalization
  event Finalized();

  //***************************************************
  //  Constructor
  //*************************************************** 
  function BoomrCoinCrowdsale() {       

  }

  function StartCrowdsale(address _token, address _wallet, uint256 _startTime) onlyOwner{
    require(_startTime >= now); 
    require(_token != 0x0);
    require(_wallet != 0x0);

    // Set the start time
    startTime = _startTime;

    // Assign the token
    boomrToken = BoomrCoin(_token);  

    // Wallet for funds
    wallet = _wallet;

    // Refund vault
    vault = new RefundVault(wallet);        

    // minimum amount of funds to be raised in weis
    minGoal = 17500 * 10**18; // Approx 3.5M Dollars
    //minGoal = 5 * 10**18; // Approx 3.5M Dollars

    // Tokens for presale
    tokenLimitPresale    =  30000000 * 10**18;
    //uint256 tokenLimitPresale    =  5 * 10**18;  // for testing

    // Tokens for crowdsale 
    tokenLimitCrowdsale  = 120000000 * 10**18;
    //uint256 tokenLimitCrowdsale  = 5 * 10**18;

    // Presale discount for each phase
    presaleDiscount    = 25 * 10**16;  // 25%
    crowdsaleDiscount1 = 15 * 10**16;  // 15%
    crowdsaleDiscount2 = 10 * 10**16;  // 10%
    crowdsaleDiscount3 =  5 * 10**16;  //  5%  
    crowdsaleDiscount4 =           0;  //  0%

    // durations for each phase
    presaleDuration    = 30;//604800; // One Week in seconds
    crowdsaleDuration1 = 30;//604800; // One Week in seconds
    crowdsaleDuration2 = 30;//604800; // One Week in seconds
    crowdsaleDuration3 = 30;//604800; // One Week in seconds
    crowdsaleDuration4 = 30;//604800; // One Week in seconds

  }

  //***************************************************
  //  Runtime state checks
  //***************************************************

  function currentStateActive() public constant returns ( bool presaleWaitPhase,
                                                          bool presalePhase,
                                                          bool crowdsalePhase1,
                                                          bool crowdsalePhase2,
                                                          bool crowdsalePhase3,
                                                          bool crowdsalePhase4,
                                                          bool buyable,
                                                          bool distributable,
                                                          bool reachedEtherGoal,
                                                          bool completed,
                                                          bool finalizedAndClosed,
                                                          bool halted){

    return (  isPresaleWaitPhase(),
              isPresalePhase(),
              isCrowdsalePhase1(),
              isCrowdsalePhase2(),
              isCrowdsalePhase3(),
              isCrowdsalePhase4(),
              isBuyable(),
              isDistributable(),
              goalReached(),
              isCompleted(),
              finalized,
              halted);
  }

  function currentStateSales() public constant returns (uint256 PresaleTokenPrice,
                                                        uint256 BaseTokenPrice,
                                                        uint256 CrowdsaleTokenPrice1,
                                                        uint256 CrowdsaleTokenPrice2,
                                                        uint256 CrowdsaleTokenPrice3,
                                                        uint256 CrowdsaleTokenPrice4,
                                                        uint256 TokenPresaleTotalSold,
                                                        uint256 TokenCrowdsaleTotalSold,
                                                        uint256 TotalBackers,
                                                        uint256 WeiRaised,
                                                        address Wallet,
                                                        uint256 GoalInWei,
                                                        uint256 RemainingTokens){

    return (  presaleTokenPrice,
              baseTokenPrice,
              crowdsaleTokenPrice1,
              crowdsaleTokenPrice2,
              crowdsaleTokenPrice3,
              crowdsaleTokenPrice4,
              tokenPresaleTotalSold,
              tokenCrowdsaleTotalSold,
              totalBackers,
              weiRaised,
              wallet,
              minGoal,
              getContractTokenBalance());

  }

  function currentTokenDistribution() public constant returns (uint256 PresalePhaseTokens,
                                                               uint256 CrowdsalePhase1Tokens,
                                                               uint256 CrowdsalePhase2Tokens,
                                                               uint256 CrowdsalePhase3Tokens,
                                                               uint256 CrowdsalePhase4Tokens){

    return (  presaleTokenSent,
              crowdsaleTokenSold1,
              crowdsaleTokenSold2,
              crowdsaleTokenSold3,
              crowdsaleTokenSold4);

  }

  function isPresaleWaitPhase() internal constant returns (bool){
    return startTime >= now;
  }

  function isPresalePhase() internal constant returns (bool){
    return startTime < now && (startTime + presaleDuration) >= now;
  }

  function isCrowdsalePhase1() internal constant returns (bool){
    return (startTime + presaleDuration) < now && (startTime + presaleDuration + crowdsaleDuration1) >= now;
  }

  function isCrowdsalePhase2() internal constant returns (bool){
    return (startTime + presaleDuration + crowdsaleDuration1) < now && (startTime + presaleDuration + crowdsaleDuration1 + crowdsaleDuration2) >= now;
  }

  function isCrowdsalePhase3() internal constant returns (bool){
    return (startTime + presaleDuration + crowdsaleDuration1 + crowdsaleDuration2) < now && (startTime + presaleDuration + crowdsaleDuration1 + crowdsaleDuration2 + crowdsaleDuration3) >= now;
  }

  function isCrowdsalePhase4() internal constant returns (bool){
    return (startTime + presaleDuration + crowdsaleDuration1 + crowdsaleDuration2 + crowdsaleDuration3) < now && (startTime + presaleDuration + crowdsaleDuration1 + crowdsaleDuration2 + crowdsaleDuration3 + crowdsaleDuration4) >= now;
  }

  function isCompleted() internal constant returns (bool){
    return (startTime + presaleDuration + crowdsaleDuration1 + crowdsaleDuration2 + crowdsaleDuration3 + crowdsaleDuration4) < now;
  }

  function isDistributable() internal constant returns (bool){
    return (startTime + presaleDuration) < now;
  }

  function isBuyable() internal constant returns (bool){
    return isDistributable() && !isCompleted();
  }

  // Test if we reached the goal
  function goalReached() internal constant returns (bool) {
    return weiRaised >= minGoal;
  }

  //***************************************************
  //  Contract's token balance
  //***************************************************
  function getContractTokenBalance() internal constant returns (uint256) {
    return boomrToken.balanceOf(this);
  }

  //***************************************************
  //  Emergency functions
  //*************************************************** 
  function halt() onlyOwner{
    halted = true;
  }

  function unHalt() onlyOwner{
    halted = false;
  }

  //***************************************************
  //  Update all the prices
  //***************************************************
  function updatePrices() internal {

    presaleTokenPrice = weiRaised.mul(1 ether).div(tokenLimitPresale);
    baseTokenPrice = (presaleTokenPrice * (1 ether)) / ((1 ether) - presaleDiscount);
    crowdsaleTokenPrice1 = baseTokenPrice - ((baseTokenPrice * crowdsaleDiscount1)/(1 ether));
    crowdsaleTokenPrice2 = baseTokenPrice - ((baseTokenPrice * crowdsaleDiscount2)/(1 ether));
    crowdsaleTokenPrice3 = baseTokenPrice - ((baseTokenPrice * crowdsaleDiscount3)/(1 ether));
    crowdsaleTokenPrice4 = baseTokenPrice - ((baseTokenPrice * crowdsaleDiscount4)/(1 ether));
  }

  //***************************************************
  //  Default presale and token purchase
  //***************************************************  
  function () payable {
    if(msg.value == 0 && isDistributable())
    {
      distributePresale(msg.sender);
    }else{
      require(!isPresaleWaitPhase() && !isCompleted());

      // Select purchase action
      if (isPresalePhase()){

        // Presale deposit
        depositPresale(msg.sender);

      }else{
        // Buy the tokens
        buyTokens(msg.sender);
      }
    }
  }

  //***************************************************
  //  Low level deposit
  //***************************************************  
  function depositPresale(address beneficiary) payable {
    require(!halted);
    require(beneficiary != 0x0);
    require(msg.value != 0);

    // Amount invested
    uint256 weiAmount = msg.value;

    // Send funds to main wallet
    forwardFunds();

    // Total innvested so far
    weiRaised = weiRaised.add(weiAmount);

    // Mark the deposits, add if they deposit more than once
    deposits[beneficiary] += weiAmount;
    totalBackers++;

    // Determine the current price
    updatePrices();

    // emit event for logging
    PresalePurchase(msg.sender, beneficiary, weiAmount);

  }

  //***************************************************
  //  Token distribution for presale purchasers
  //***************************************************  
  function distributePresale(address beneficiary) {
    require(!halted);
    require(isDistributable());
    require(deposits[beneficiary] > 0);
    require(beneficiary != 0x0);

    // Amount investesd
    uint256 weiDeposit = deposits[beneficiary];

    // prevent re-entrancy
    deposits[beneficiary] = 0;

    // tokens out
    uint256 tokensOut = weiDeposit.mul(1 ether).div(presaleTokenPrice);

    //trackTokens(tokensOut, index);
    tokenPresaleTotalSold += tokensOut;
    //presaleTokenSent += tokensOut;

    // transfer tokens
    boomrToken.transfer(beneficiary, tokensOut);

    // emit event for logging
    PresaleDistribution(msg.sender, beneficiary, tokensOut);

  }

  //***************************************************
  //  Low level purchase
  //***************************************************  
  function buyTokens(address beneficiary) payable {
    require(!halted);
    require(beneficiary != 0x0);
    require(msg.value != 0);
    require(isCrowdsalePhase1() || isCrowdsalePhase2() || isCrowdsalePhase3() || isCrowdsalePhase4());

    uint256 price = 0;

    if (isCrowdsalePhase1()){
      price = crowdsaleTokenPrice1;
    }else if (isCrowdsalePhase2()){
      price = crowdsaleTokenPrice2;
    }else if (isCrowdsalePhase3()){
      price = crowdsaleTokenPrice3;
    }else if (isCrowdsalePhase4()){
      price = crowdsaleTokenPrice4;
    }else{
      price = baseTokenPrice;
    }

    // Amount of ether sent
    uint256 weiAmount = msg.value;

    // calculate reward
    uint256 tokensOut = weiAmount.mul(1 ether).div(price);

    // make sure we are not over sold
    require(tokensOut + tokenCrowdsaleTotalSold < tokenLimitCrowdsale);

    // Send funds to main wallet
    forwardFunds();     

    // Update raised
    weiRaised = weiRaised.add(weiAmount);

    // Track purchases
    purchases[beneficiary] += weiRaised;

    // track issued    
    tokenCrowdsaleTotalSold += tokensOut;

    if (isCrowdsalePhase1()){
      crowdsaleTokenSold1 += tokensOut;
    }else if (isCrowdsalePhase2()){
      crowdsaleTokenSold2 += tokensOut;
    }else if (isCrowdsalePhase3()){
      crowdsaleTokenSold3 += tokensOut;
    }else if (isCrowdsalePhase4()){
      crowdsaleTokenSold4 += tokensOut;
    }

    // Send to buyers
    boomrToken.transfer(beneficiary, tokensOut);

    // Emit event for logging
    TokenPurchase(msg.sender, beneficiary, weiAmount, tokensOut);

    // Track the backers
    totalBackers++;

  }

  // For deposits that do not come thru the contract
  function externalDeposit(address dep, uint256 amount) onlyOwner{
    require(isDistributable());

    uint256 tokensOut = amount.mul(1 ether).div(baseTokenPrice);

    //trackTokens(tokensOut, index);
    tokenCrowdsaleTotalSold += tokensOut;

    // Update raised
    weiRaised = weiRaised.add(amount);

    // transfer tokens
    boomrToken.transfer(dep, tokensOut);

  }

  // send ether to the fund collection wallet
  // override to create custom fund forwarding mechanisms
  function forwardFunds() internal {
    //wallet.transfer(msg.value);
    vault.deposit.value(msg.value)(msg.sender);
  }

    // if crowdsale is unsuccessful, investors can claim refunds here
  function claimRefund() {
    require(!halted);
    require(finalized);    
    require(!goalReached());

    vault.refund(msg.sender);
  }

  // Should be called after crowdsale ends, to do
  // some extra finalization work
  function finalize() onlyOwner {
    require(!finalized);  
    require(isCompleted());

    if (goalReached()) {
      vault.close();
    } else {
      vault.enableRefunds();
    }
    
    finalized = true;
    Finalized();
  }

}
