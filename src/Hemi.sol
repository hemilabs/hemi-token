// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Hemi is ERC20 {
    constructor() ERC20("hemi", "HEMI") {
    }  
}