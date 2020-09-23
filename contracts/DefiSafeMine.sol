pragma solidity 0.6.0;
import "./DefiSafeTokenInterface.sol";
import "./SafeMath.sol";

contract DefiSafeMine {

    using SafeMath for uint256;

    address payable owner;

    struct User {
        address name;
        uint256 tokenID;
        //lp
        uint256 userTokenAmount;
    }

    struct TokenPool {
        uint256 tokenID;
        uint256 poolTokenAmount;
        uint256 userAmount;
    }

    struct PlatformData {
        uint256 mortgageTokenTotal;// Token total
    }
    //Environmental statistics
    PlatformData public platformDataManager;

     //TokenID protocol
    mapping(uint256 => address) public tokenIDProtocol;
    //Token Pool management
    mapping(uint256 => TokenPool) private tokenPools;

    struct LockedAccountsStruct {
        uint256 totalAmount;
        mapping(uint256 => address) lockAccounts;
    }
    //Control difficulty account management
    LockedAccountsStruct private lockAccountsManager;

    address public defiSafeTokenAddress;
    uint256 constant private C1 = 5;
    uint256 constant private C2 = 14;
    uint256 constant private DSE_TOKEN_INIT_TOTAL = 1000000000 * 1e18;

    struct MineManagerStruct {
        uint256 totalMinersCount;
        uint256 mineTotalTokens;
        //10:Have authority to mine
        mapping(address => uint256) minersPermissions;
    }

    address private communityAccount;
    address public communityRatio;

    struct MineManagerStruct {
        uint256 totalMinersCount;
        uint256 mineTotalTokens;
        //10:Have authority to mine
        mapping(address => uint256) minersPermissions;
    }
    MineManagerStruct private mineManager;

    event MineTokensEvent(address miner,address user,uint256 mineTokens);
    event Deposit(uint256 tokenID,uint256 tokenAmount);
    event UnlockAssets(uint256 tokenID,uint256 tokenAmount);

    constructor() public {
        owner = msg.sender;
        mineManager = MineManagerStruct({totalMinersCount: 0,mineTotalTokens:0});
        lockAccountsManager = LockedAccountsStruct({totalAmount : 1});
        platformDataManager = PlatformData({mortgageTokenTotal: 0});
        lockAccountsManager.lockAccounts[0] = address(this);
    }

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    function setCommunityRatio(uint256 _ratio)public onlyOwner{
        communityRatio = _ratio;
    }


    //Set MortgageToken token
    function addMortgageToken(uint256 _tokenID,address _mortgageToken) public onlyOwner{
        require(tokenIDProtocol[_tokenID] == address(0),"Token is already supported.");
        require(_mortgageToken != address(0),"Invalid token address .");
        require(_tokenID == dataStatistics.mortgageTokenTotal,"TokenID error .");
        tokenIDProtocol[_tokenID] = _mortgageToken;
        platformDataManager.mortgageTokenTotal = dataStatistics.mortgageTokenTotal.add(1);
        distributionTokenPool(_tokenID);
    }

        //Distribute token pool
    function distributionTokenPool(uint256 _tokenID) private{
        tokenPools[_tokenID] = TokenPool({
            tokenID: _tokenID,
            poolTokenAmount: 0,
            userAmount: 0,
        });
    }

    function deposit(uint256 _tokenType,uint256 _tokenAmount)external payable{
        require(_tokenType < platformDataManager.mortgageTokenTotal,"Deposit TokenType error .");
        require(_tokenAmount > 0,"Deposit TokenAmount error .");
        address tokenAddress = tokenIDProtocol[_tokenType];
        require(tokenAddress != address(0),"Deposit tokenAddress error .");
        ERC20 tokenManager = ERC20(tokenAddress);
        require(_tokenAmount <= tokenManager.balanceOf(msg.sender),"Lack of balance .");

        TokenPool storage pool = tokenPools[_tokenType];;
        User storage user = pool.users[msg.sender];
        pool.userAmount = pool.userAmount + 1;
        pool.poolTokenAmount = pool.poolTokenAmount + _tokenAmount;
        
        user.name = msg.sender;
        user.tokenID = _tokenType;
        user.userTokenAmount = _tokenAmount;

        emit Deposit(_tokenType,_tokenAmount);
    }


    function unlockAssets(uint256 _tokenType)external {
        require(_tokenType < platformDataManager.mortgageTokenTotal,"Deposit TokenType error .");
        address tokenAddress = tokenIDProtocol[_tokenType];
        require(tokenAddress != address(0),"TokenAddress error .");
        ERC20 tokenManager = ERC20(tokenAddress);
        
        TokenPool storage pool = tokenPools[_tokenType];;
        User storage user = pool.users[msg.sender];
        require(user.userTokenAmount > 0,"No Deposit .");
        require(tokenManager(msg.sender,user.userTokenAmount),"UnlockAssets error .");

        uint256 unlock =  user.userTokenAmount;
        pool.userAmount = pool.userAmount - 1;
        pool.poolTokenAmount = pool.poolTokenAmount - user.userTokenAmount;
        user.userTokenAmount = 0;

        emit UnlockAssets(_tokenType,unlock);
    }


    function setCommunityAccount(address _communityAddress)public onlyOwner{
        require(_communityAddress != address(0),"communityAddress error !");
        communityAccount = _communityAddress;
    }

    function setLockAccountsManager(uint256 accountID,address accountAddress)public onlyOwner{
        require(accountAddress != address(0),"accountAddress error !");
        require(lockAccountsManager.lockAccounts[accountID] == address(0),"accountAddress is already supported.");
        require(lockAccountsManager.totalAmount == accountID,"accountID error.");

        lockAccountsManager.lockAccounts[accountID] = accountAddress;
        lockAccountsManager.totalAmount = lockAccountsManager.totalAmount+1;
    }

    function setDefiSafeMineAddress(address _addr)public onlyOwner {
        require(_addr != address(0),"DefiSafeMineAddress error .");
        uint256 authority = mineManager.minersPermissions[_addr];
        require(authority != 10,"Has authorized .");
        mineManager.minersPermissions[_addr] = 10;
        mineManager.totalMinersCount = mineManager.totalMinersCount.add(1);
    }

    function removeDefiSafeMineAddress(address _addr)public onlyOwner {
        require(_addr != address(0),"DefiSafeMineAddress error .");
        uint256 authority = mineManager.minersPermissions[_addr];
        require(authority == 10,"No Authority .");
        mineManager.minersPermissions[_addr] = 0;
        mineManager.totalMinersCount = mineManager.totalMinersCount.sub(1);
    }

    function setDefiSafeTokenAddress(address _addr)public onlyOwner {
        require(_addr != address(0),"DefiSafeTokenAddress error .");
        defiSafeTokenAddress = _addr;
    }

    function getMinerPermission(address miner) private returns(bool){
        uint256 authority = mineManager.minersPermissions[miner];
        if(authority == 10){
            return true;
        }else{
            return false;
        }
    }

    function getUserDepositTokenType(address _user)public view returns(uint256 isDesposit,uint256 _tokenType){
        require(_user != address(0),"User address error .");
        for(uint tokenID = 0;tokenID<(platformDataManager.mortgageTokenTotal,tokenID++){
            TokenPool storage pool = tokenPools[tokenID];;
            User storage user = pool.users[_user];
            if(user.userTokenAmount > 0){
                return (1,tokenID);
            }
        }
        return (0,0);
    }

    function increaseOutput(uint256 _outDSE,address _user)public view returns(uint256){
        require(_outDSE > 0,"NO OUT");
        require(_user != address(0),"User address error .");
        (uint256 isDesposit,uint256 tokenType) = getUserDepositTokenType(_user);
        if(isDesposit){
            TokenPool storage pool = tokenPools[tokenType];;
            User storage user = pool.users[_user];
            uint256 addOutDSE = mulDiv(outDSE,user.userTokenAmount,pool.poolTokenAmount);
            return outDSE.add(addOutDSE);
        }
        return outDSE;
    }

    function startMine(uint256 userTotalAssets,uint256 loseAssets,address receiveAddress) public{
        require(getMinerPermission(msg.sender),"No permission .");
        require(receiveAddress != address(0),"rec address error .");
        require(defiSafeTokenAddress != address(0),"DefiSafeTokenAddress no init .");
        require(lockAccountsManager.totalAmount > 2,"lockAccountsManager no set .");
        require(communityAccount != address(0),"communityAccount error !");
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
        uint256 tokenMineBalance = defiSafeToken.balanceOf(address(this));
        require(tokenMineBalance > 0,"No DSE");
        require(userTotalAssets > 0,"No userTotalAssets");
        require(loseAssets > 0,"No loseAssets");

        uint256 baseOutDSE = releaseRulesDSE(userTotalAssets);
        uint256 loseOutDSE = releaseRulesDSE(loseAssets);
    
        uint256 outDSEStage = mineManager.mineTotalTokens.add(baseOutDSE);
        if(outDSEStage <= (10000000 * 1e18)){
            loseOutDSE = loseOutDSE.mul(10);
        }else if(outDSEStage <= (40000000 * 1e18)){
            loseOutDSE = loseOutDSE.mul(4);
        }else if(outDSEStage <= (100000000 * 1e18)){
            loseOutDSE = loseOutDSE.mul(3);
        }else{
            loseOutDSE = loseOutDSE.mul(2);;
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

        DefiSafeTokenInterface defiSafeToken = DefiSafeTokenInterface(defiSafeTokenAddress);
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
        DefiSafeTokenInterface defiSafeToken = DefiSafeTokenInterface(defiSafeTokenAddress);
        uint256 tokenSurplusBalance = 0;
        for(uint i = 0;i<(lockAccountsManager.totalAmount);i++){
            address lockAccount = lockAccountsManager.lockAccounts[i];
            uint256 lockAccountTokenBalance = defiSafeToken.balanceOf(lockAccount);
            tokenSurplusBalance = tokenSurplusBalance.add(lockAccountTokenBalance);
        }
        uint256 tokenFree = DSE_TOKEN_INIT_TOTAL.sub(tokenSurplusBalance);
        return tokenFrees;
    }

    function getLockAccount(uint256 accountID)public view returns(address){
        require(accountID < lockAccountsManager.totalAmount,"accountID error .");
        return lockAccountsManager.lockAccounts[accountID];
    }


     function mulDiv (uint256 _x, uint256 _y, uint256 _z) public pure returns (uint256) {
        uint256 temp = _x.mul(_y);
        return temp.div(_z);
    }
}