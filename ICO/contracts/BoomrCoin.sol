pragma solidity ^0.4.11;

import 'zeppelin-solidity/contracts/ownership/Ownable.sol';
import 'zeppelin-solidity/contracts/token/PausableToken.sol';
import 'zeppelin-solidity/contracts/math/SafeMath.sol';

//*****************************************************
// * @title BoomrCoin 
// * @dev  Initial supply is 500000000
//   Supply is intended to be fixed, but is mintable
//   by the owner if needed in the future.
//   StartMinting is added to the base class.
// ****************************************************
contract BoomrCoin is PausableToken {
  string public name = "BOOMR COIN - LIBLOB";
  string public symbol = "BMR";
  uint256 public decimals = 18;
  uint256 public constant INITIAL_SUPPLY = 500000000 * 10**18;
  
  /**
   * @dev Contructor that gives msg.sender all of existing tokens.
   */
  function BoomrCoin() {
    totalSupply = INITIAL_SUPPLY;
    balances[msg.sender] = INITIAL_SUPPLY;
  }
}