pragma solidity 0.6.0;


interface DefiSafeMine {
    function startMine(uint256 userTotalAssets,address receiveAddress) external;
    function getTotalTokensOfMine()external view returns(uint256);
    function getTotalTokensOfFree()external view returns(uint256);
}
