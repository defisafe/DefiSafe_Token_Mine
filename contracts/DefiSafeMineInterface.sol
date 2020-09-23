pragma solidity 0.6.0;

interface DefiSafeMine {
    function startMine(uint256 userTotalAssets,uint256 loseAssets,address receiveAddress) external;
    function getUserClaimAmount(uint256 userTotalAssets,uint256 loseAssets,address receiveAddress) external view returns(uint256 userTokens,uint256 communityTokens);
    function getTotalTokensOfMine()external view returns(uint256);
    function getTotalTokensOfFree()external view returns(uint256);
}
