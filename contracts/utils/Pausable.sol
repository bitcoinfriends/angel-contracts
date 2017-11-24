pragma solidity ^0.4.15;


import "./Manageable.sol";


/**
 * @title Pausable
 * @dev Base contract which allows children to implement an emergency stop mechanism.
 * @dev Based on zeppelin's Pausable, but integrated with Manageable
 * @dev Contract is in paused state by default and should be explicitly unlocked
 */
contract Pausable is Manageable {

  /**
   * Events
   */

  event PauseEvent();
  event UnpauseEvent();


  /**
   * Storage
   */

  bool paused = true;


  /**
   * @dev modifier to allow actions only when the contract IS paused
   */
  modifier whenContractNotPaused() {
    require(paused == false);
    _;
  }

  /**
   * @dev modifier to allow actions only when the contract IS NOT paused
   */
  modifier whenContractPaused {
    require(paused == true);
    _;
  }

  /**
   * @dev called by the manager to pause, triggers stopped state
   */
  function pauseContract() external onlyAllowedManager('pause_contract') whenContractNotPaused {
    paused = true;
    PauseEvent();
  }

  /**
   * @dev called by the manager to unpause, returns to normal state
   */
  function unpauseContract() external onlyAllowedManager('unpause_contract') whenContractPaused {
    paused = false;
    UnpauseEvent();
  }

  /**
   * @dev The getter for "paused" contract variable
   */
  function getPaused() external constant returns (bool) {
    return paused;
  }
}
