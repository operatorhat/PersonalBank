// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IPool} from "aave-v3-core/contracts/interfaces/IPool.sol";
import {IERC20} from "aave-v3-core/contracts/dependencies/openzeppelin/contracts/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract PersonalBank {
    using SafeERC20 for IERC20;

    error NotOwner();
    error ZeroAmount();
    error ZeroAddress();

    event Supplied(address indexed asset, uint256 amount);
    event Withdrawn(address indexed asset, uint256 amount);
    event AavePoolUpdated(address indexed newPool);

    address public immutable OWNER;
    IPool public aavePool;

    modifier onlyOwner() {
        if (msg.sender != OWNER) revert NotOwner();
        _;
    }

    constructor(address _aavePool) {
        if (_aavePool == address(0)) revert ZeroAddress();
        OWNER = msg.sender;
        aavePool = IPool(_aavePool);
    }

    function supply(address asset, uint256 amount) external onlyOwner {
    if (amount == 0) revert ZeroAmount();
    emit Supplied(asset, amount);

    IERC20 token = IERC20(asset);
    token.approve(address(aavePool), 0);
    token.approve(address(aavePool), amount);

    aavePool.supply(asset, amount, address(this), 0);
}


    function withdraw(address asset, uint256 amount) external onlyOwner {
        if (amount == 0) revert ZeroAmount();
        emit Withdrawn(asset, amount);
        aavePool.withdraw(asset, amount, address(this));
    }

    function setAavePool(address _newPool) external onlyOwner {
        if (_newPool == address(0)) revert ZeroAddress();
        aavePool = IPool(_newPool);
        emit AavePoolUpdated(_newPool);
    }
}
