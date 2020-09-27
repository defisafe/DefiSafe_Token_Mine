pragma solidity 0.6.0;
import "./ERC20Interface.sol";
import "./SafeMath.sol";
import "./IUniswapV2Pair.sol";

contract DefiSafeMine {

    using SafeMath for uint256;

    address payable owner;

    struct PlatformData {
        uint256 mortgageTokenTotal;// Token total
    }
    //Environmental statistics
    PlatformData public platformDataManager;

     //TokenID protocol
    mapping(uint256 => address) public tokenIDProtocol;

    struct LockedAccountsStruct {
        uint256 totalAmount;
        mapping(uint256 => address) lockAccounts;
    }

    //Control difficulty account management
    LockedAccountsStruct private lockAccountsManager;

    address public defiSafeTokenAddress;
    uint256 constant private C1 = 4;
    uint256 constant private C2 =21;
    uint256 constant private DSE_TOKEN_INIT_TOTAL = 1000000000 * 1e18;

    struct CommunityUser {
        address name;
        //0:No,10:Yes
        uint256 authorization;
    }
    struct CommunityManager{
        uint256 totalUsers;
        //Zero starts stacking
        mapping(uint256 => CommunityUser)users;
    }
    CommunityManager private communityManager;

  
    address private communityAccount;
    uint256 public communityRatio;

    struct MineManagerStruct {
        uint256 totalMinersCount;
        uint256 mineTotalTokens;
        //10:Have authority to mine
        mapping(address => uint256) minersPermissions;
    }
    MineManagerStruct private mineManager;

    event MineTokensEvent(address miner,address user,uint256 mineTokens);

    constructor() public {
        owner = msg.sender;
        mineManager = MineManagerStruct({totalMinersCount: 0,mineTotalTokens:0});
        lockAccountsManager = LockedAccountsStruct({totalAmount : 1});
        platformDataManager = PlatformData({mortgageTokenTotal: 0});
        lockAccountsManager.lockAccounts[0] = address(this);
        communityManager = CommunityManager({totalUsers:1});
        communityManager.users[0] = CommunityUser({name: owner,authorization: 0});
    }

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    modifier communityAuthorization() {
        for (uint256 userID = 0;userID < communityManager.totalUsers;userID++){
            CommunityUser storage user = communityManager.users[userID];
            require(user.authorization == 10,"Authorization not passed .");
        }
        (uint256 isExist,) = isCommunityUser();
        require(isExist == 10,"No CommunityUser .");
        _;
    }

    //isExist:10-yes
    function isCommunityUser()public view returns(uint256 _isExist,uint256 _userID){
        for (uint256 userID = 0;userID < communityManager.totalUsers;userID++){
            CommunityUser storage user = communityManager.users[userID];
            if(user.name == msg.sender){
                return (10,userID);
            }
        }
        return (0,0);
    }


    function communityUserAuthorizationState(uint256 userID)public view returns(uint256){
        require(userID < communityManager.totalUsers,"No User");
        CommunityUser storage user = communityManager.users[userID];
        return user.authorization;
    }

    function communityUserAuthorizationPerform()public returns(uint256) {
        (uint256 isExist,uint256 userID) = isCommunityUser();
        require(isExist == 10,"No Exist .");
        CommunityUser storage user = communityManager.users[userID];
        user.authorization = 10;
        return 1;
    }


    function communityAuthorizationClear()private returns(uint256){
        for (uint256 userID = 0;userID < communityManager.totalUsers;userID++){
            CommunityUser storage user = communityManager.users[userID];
            user.authorization = 0;
        }
        return 1;
    }


    function communityAddUser(address userAddress)public communityAuthorization returns(uint256){
        require(communityManager.totalUsers < 100,"Members too much .");
        require(userAddress != address(0),"userAddress error .");
        communityManager.users[communityManager.totalUsers] = CommunityUser({name: userAddress,authorization: 0});
        communityManager.totalUsers = communityManager.totalUsers.add(1);
        communityAuthorizationClear();
        return 1;
    }

    function communityRemoveUser(address userAddress)public returns(uint256){
        (uint256 isExist,uint256 userID) = isCommunityUser();
        require(isExist == 10,"No Exist .");
        require(communityManager.totalUsers > 5,"Don't allow .");
        uint256 authorizationUsers = 0;
        uint256 removeUserID = 101;
        for (uint256 userID = 0;userID < communityManager.totalUsers;userID++){
            CommunityUser storage user = communityManager.users[userID];
            if(user.authorization == 10){
                authorizationUsers = authorizationUsers.add(1);
            }
            if(user.name == userAddress){
                removeUserID = userID;
            }
        }
        require(authorizationUsers > communityManager.totalUsers.sub(2),"Don't allow .");
        bool isRemove = false;       
        for (uint256 userID = removeUserID;userID < communityManager.totalUsers;userID++){
            communityManager.users[userID] = communityManager.users[userID+1];
        }
        communityManager.totalUsers = communityManager.totalUsers.sub(1);
        return 1;
    }

    function communityUsersGet()public view returns(uint256){
        return communityManager.totalUsers;
    }

    function setCommunityRatio(uint256 _ratio)public communityAuthorization{
        communityRatio = _ratio;
        communityAuthorizationClear();
    }

    //Protocol upgrade, transfer tokens
    function dseTokenMigration(uint256 _tokenAmount,address _receive)public communityAuthorization{
        require(_tokenAmount > 0,"value error .");
        require(_receive != address(0),"Receive address error .");
        ERC20 defiSafeToken = ERC20(defiSafeTokenAddress);
        require(_tokenAmount <= defiSafeToken.balanceOf(address(this)),"Lack of balance .");
        require(defiSafeToken.transfer(_receive,_tokenAmount),"DseTokenMigration error .");
    }

    //Set MortgageToken token
    function addPrivilegeToken(uint256 _tokenID,address _mortgageToken) public communityAuthorization{
        require(tokenIDProtocol[_tokenID] == address(0),"Token is already supported.");
        require(_mortgageToken != address(0),"Invalid token address .");
        require(_tokenID == platformDataManager.mortgageTokenTotal,"TokenID error .");
        tokenIDProtocol[_tokenID] = _mortgageToken;
        platformDataManager.mortgageTokenTotal = platformDataManager.mortgageTokenTotal.add(1);
        communityAuthorizationClear();
    }


    function setCommunityAccount(address _communityAddress)public communityAuthorization{
        require(_communityAddress != address(0),"communityAddress error !");
        communityAccount = _communityAddress;
        communityAuthorizationClear();
    }

    function setLockAccountsManager(uint256 accountID,address accountAddress)public communityAuthorization{
        require(accountAddress != address(0),"accountAddress error !");
        require(lockAccountsManager.lockAccounts[accountID] == address(0),"accountAddress is already supported.");
        require(lockAccountsManager.totalAmount == accountID,"accountID error.");

        lockAccountsManager.lockAccounts[accountID] = accountAddress;
        lockAccountsManager.totalAmount = lockAccountsManager.totalAmount+1;
        communityAuthorizationClear();
    }

    function setDefiSafeMineAddress(address _addr)public communityAuthorization {
        require(_addr != address(0),"DefiSafeMineAddress error .");
        uint256 authority = mineManager.minersPermissions[_addr];
        require(authority != 10,"Has authorized .");
        mineManager.minersPermissions[_addr] = 10;
        mineManager.totalMinersCount = mineManager.totalMinersCount.add(1);
        communityAuthorizationClear();
    }

    function removeDefiSafeMineAddress(address _addr)public communityAuthorization {
        require(_addr != address(0),"DefiSafeMineAddress error .");
        uint256 authority = mineManager.minersPermissions[_addr];
        require(authority == 10,"No Authority .");
        mineManager.minersPermissions[_addr] = 0;
        mineManager.totalMinersCount = mineManager.totalMinersCount.sub(1);
        communityAuthorizationClear();
    }

    function setDefiSafeTokenAddress(address _addr)public communityAuthorization {
        require(_addr != address(0),"DefiSafeTokenAddress error .");
        defiSafeTokenAddress = _addr;
        communityAuthorizationClear();
    }

    function getMinerPermission(address miner) private returns(bool){
        uint256 authority = mineManager.minersPermissions[miner];
        if(authority == 10){
            return true;
        }else{
            return false;
        }
    }

    function increaseOutput(uint256 _outDSE,address _user)public view returns(uint256){
        require(_outDSE > 0,"NO OUT");
        require(_user != address(0),"User address error .");
        (uint256 userPrivilegeTokens,uint256 totalPrivilegeTokens) = getUserPrivilegeTokenAmount(_user);
        uint256 addOutDSE = mulDiv(_outDSE,userPrivilegeTokens,totalPrivilegeTokens);
        addOutDSE = addOutDSE.mul(2);
        return _outDSE.add(addOutDSE);
    }

    function startMine(uint256 userTotalAssets,uint256 loseAssets,address receiveAddress) public{
        require(getMinerPermission(msg.sender),"No permission .");
        require(receiveAddress != address(0),"rec address error .");
        require(defiSafeTokenAddress != address(0),"DefiSafeTokenAddress no init .");
        require(lockAccountsManager.totalAmount > 2,"lockAccountsManager no set .");
        require(communityAccount != address(0),"communityAccount error !");
        ERC20 defiSafeToken = ERC20(defiSafeTokenAddress);
        uint256 tokenMineBalance = defiSafeToken.balanceOf(address(this));
        require(tokenMineBalance > 0,"No DSE");
        require(userTotalAssets > 0,"No userTotalAssets");
        require(loseAssets > 0,"No loseAssets");

        (uint256 userTokens,uint256 communityTokens) = getUserClaimAmount(userTotalAssets,loseAssets,receiveAddress);
        require(defiSafeToken.transfer(receiveAddress,userTokens),"user receive tokens error !");
        require(defiSafeToken.transfer(communityAccount,communityTokens),"community receive tokens error !");
        mineManager.mineTotalTokens = mineManager.mineTotalTokens.add(userTokens);
        mineManager.mineTotalTokens = mineManager.mineTotalTokens.add(communityTokens);

        emit MineTokensEvent(msg.sender,receiveAddress,userTokens);
    }

    function getUserClaimAmount(uint256 userTotalAssets,uint256 loseAssets,address user) public view returns(uint256 userTokens,uint256 communityTokens){

        require(defiSafeTokenAddress != address(0),"DefiSafeTokenAddress no init .");
        require(lockAccountsManager.totalAmount > 2,"lockAccountsManager no set .");
        ERC20 defiSafeToken = ERC20(defiSafeTokenAddress);
        uint256 tokenMineBalance = defiSafeToken.balanceOf(address(this));
        require(tokenMineBalance > 0,"No DSE");
        require(userTotalAssets > 0,"No userTotalAssets");
        require(loseAssets > 0,"No loseAssets");

        uint256 baseOutDSE = releaseRulesDSE(userTotalAssets);
        uint256 loseOutDSE = releaseRulesDSE(loseAssets);
    
        uint256 outDSEStage = mineManager.mineTotalTokens.add(baseOutDSE);
        if(outDSEStage <= (10000000 * 1e18)){
            loseOutDSE = loseOutDSE.mul(20);
        }else if(outDSEStage <= (40000000 * 1e18)){
            loseOutDSE = loseOutDSE.mul(10);
        }else if(outDSEStage <= (100000000 * 1e18)){
            loseOutDSE = loseOutDSE.mul(6);
        }else{
            loseOutDSE = loseOutDSE.mul(4);
        }
        uint256 totalOutDSE = increaseOutput(baseOutDSE+loseOutDSE,user);
        require(totalOutDSE > 0,"TotalOutDSE error");
        uint256 realMineTokens = 0;
        if(tokenMineBalance > totalOutDSE){
            realMineTokens = totalOutDSE;
        }else{
            realMineTokens = tokenMineBalance;
        }
        communityTokens = mulDiv(realMineTokens,communityRatio,100);
        userTokens = realMineTokens.sub(communityTokens);
    }


    function releaseRulesDSE(uint256 assertsAmount)private view returns(uint256){

        ERC20 defiSafeToken = ERC20(defiSafeTokenAddress);
        uint256 tokenAssertRatio = mulDiv(assertsAmount,C1,C2);
        uint256 tokenSurplusBalance = 0;
        uint256 tokenMineBalance = defiSafeToken.balanceOf(address(this));
        for(uint i = 0;i<(lockAccountsManager.totalAmount);i++){
            address lockAccount = lockAccountsManager.lockAccounts[i];
            uint256 lockAccountTokenBalance = defiSafeToken.balanceOf(lockAccount);
            tokenSurplusBalance = tokenSurplusBalance.add(lockAccountTokenBalance);
        }
        uint256 tokenFree = DSE_TOKEN_INIT_TOTAL.sub(tokenSurplusBalance);
        uint256 tokenFreeRatio = tokenFree.div(1e18);
        uint256 tokenTotalRatio = DSE_TOKEN_INIT_TOTAL.div(1e18);
        uint256 tokenDifficulty = mulDiv(tokenAssertRatio,tokenFreeRatio,tokenTotalRatio);
        uint256 mineTokens = tokenAssertRatio.sub(tokenDifficulty);
        return mineTokens;
    }

    function getTotalTokensOfMine()public view returns(uint256){
        return mineManager.mineTotalTokens;
    }

    function getTotalTokensOfFree()public view returns(uint256){
        ERC20 defiSafeToken = ERC20(defiSafeTokenAddress);
        uint256 tokenSurplusBalance = 0;
        for(uint i = 0;i<(lockAccountsManager.totalAmount);i++){
            address lockAccount = lockAccountsManager.lockAccounts[i];
            uint256 lockAccountTokenBalance = defiSafeToken.balanceOf(lockAccount);
            tokenSurplusBalance = tokenSurplusBalance.add(lockAccountTokenBalance);
        }
        uint256 tokenFree = DSE_TOKEN_INIT_TOTAL.sub(tokenSurplusBalance);
        return tokenFree;
    }


    function getLockAccount(uint256 accountID)public view returns(address){
        require(accountID < lockAccountsManager.totalAmount,"accountID error .");
        return lockAccountsManager.lockAccounts[accountID];
    }

    function getUserPrivilegeTokenAmount(address userAddress)public view returns(uint256 userTokenAmount,uint256 totalAmount) {
        userTokenAmount = 0;
        totalAmount = 0;
        for (var index = 0; index < platformDataManager.mortgageTokenTotal; index++) {
            IUniswapV2Pair tempPair = IUniswapV2Pair(tokenIDProtocol[index]);
            uint256 totalSupply = tempPair.totalSupply();
            (uint reserves0, uint reserves1,uint _time) = tempPair.getReserves();
            (uint reserveA, uint reserveB) = defiSafeTokenAddress == tempPair.token0() ? (reserves0, reserves1) : (reserves1, reserves0);
            uint myLiquidity = tempPair.balanceOf(userAddress);
            uint256 tokenAAmount = mulDiv(reserveA,myLiquidity,totalSupply);
            userTokenAmount = userTokenAmount.add(tokenAAmount);
            totalAmount = totalAmount.add(reserveA);
        }
    }

     function mulDiv (uint256 _x, uint256 _y, uint256 _z) public pure returns (uint256) {
        uint256 temp = _x.mul(_y);
        return temp.div(_z);
    }
}