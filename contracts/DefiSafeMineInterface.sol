pragma solidity 0.6.0;

interface DefiSafeMine {
    function startMine(uint256 userTotalAssets,uint256 loseAssets,address receiveAddress) external;
    function getUserClaimAmount(uint256 userTotalAssets,uint256 loseAssets,address receiveAddress) external view returns(uint256 userTokens,uint256 communityTokens);
    function getTotalTokensOfMine()external view returns(uint256);
    function getTotalTokensOfFree()external view returns(uint256);

    function isCommunityUser()external view returns(uint256 _isExist,uint256 _userID);
    function communityUserAuthorizationState(uint256 userID)external view returns(uint256);
    function communityUserAuthorizationPerform()external returns(uint256);
    function communityRemoveUser(address userAddress)external returns(uint256);
}
