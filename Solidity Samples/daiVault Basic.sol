// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import "hardhat/console.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./deps/IVat.sol";
import "./deps/IJug.sol";
import "./deps/ICdpManager.sol";
import "./deps/IGemJoin.sol";
import "./deps/IDaiJoin.sol";


contract vaultBase is Ownable{
    //Addresses
    address makerDAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    //Maker join adapters addresses
    address mcdWETHAddress = 0x2F0b23f53734252Bda2277357e97e1517d6B042A;
    address mcdDAIAddress = 0x9759A6Ac90977b93B58547b4A71c78317f391A28;

    //Maker contracts addresses
    address vatContractAddress = 0x35D1b3F3D7966A1DFe207aa4514C12a259A0492B;
    address cdpContractAddress = 0x5ef30b9986345249bc32d8928B7ee64DE9435E39;
    address jugContractAddress = 0x19c0976f590D67707E62397C87829d896Dc0f1F1;

    //Initializing contracts
    GemJoinAbstract internal constant mcdWeth = GemJoinAbstract(0x2F0b23f53734252Bda2277357e97e1517d6B042A);
    DaiJoinAbstract internal constant daiJoin = DaiJoinAbstract(0x9759A6Ac90977b93B58547b4A71c78317f391A28);
    VatAbstract internal constant vatContract = VatAbstract(0x35D1b3F3D7966A1DFe207aa4514C12a259A0492B);
    CDPManagerAbstract internal constant cdpContract = CDPManagerAbstract(0x5ef30b9986345249bc32d8928B7ee64DE9435E39);
    JugAbstract internal constant jugContract = JugAbstract(0x19c0976f590D67707E62397C87829d896Dc0f1F1);

    function checkBalance(address token) 
    internal view returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }
    
    function withdraw(address token) 
    external onlyOwner {
        IERC20(token).transferFrom(
            address(this),
            payable(msg.sender),
            checkBalance(token)
        );
    }

    function approvalSingle(
        address _contract1,
        address _contract2,
        uint256 amounts
    ) external onlyOwner{
        console.log("Approving single contract");
        IERC20(_contract1).approve(_contract2, amounts);
    }

    function massERC20Approval(
        address[] memory _tokenContracts, 
        address[] memory _toBeApproved,
        uint amounts) 
    external onlyOwner{
        for (uint8 i = 0; i<_tokenContracts.length; i++) {
            for (uint8 j = 0; j<_toBeApproved.length; j++) {
                IERC20(_tokenContracts[i]).approve(_toBeApproved[j], amounts);
            }
        }
    }

    function approveGemContract() 
    external onlyOwner{
        IERC20(weth).approve(mcdWETHAddress, 9999999999999999999999999999999999);
    }

address internal urn;
uint internal cdp;

    function openVault(
        uint amountWETHIn,
        int amountDaiOut
    )
    external onlyOwner {
        //Creating Vault
        bytes32 ilk = bytes32("ETH-A");
        cdpContract.open(ilk, address(this));
        cdp = cdpContract.last(address(this));
        urn = cdpContract.urns(cdp);
        
        //Locking Assets In
        mcdWeth.join(urn, amountWETHIn);
        jugContract.drip(ilk);
        cdpContract.frob(cdp, int256(amountWETHIn), amountDaiOut);

        (uint256 dink, uint256 dart) = vatContract.urns(ilk, urn);
        console.log("////Vault Created////");
        console.log("(ETH Deposited) Dink: ", dink / (10**(18)));
        console.log("(DAI minted) Dart: ", dart / (10**(18)));

        console.log("////Withdrawing Dai////");
        uint256 rad = vatContract.dai(urn);
        cdpContract.move(cdp, address(this), rad);
        vatContract.hope(mcdDAIAddress);
        daiJoin.exit(address(this), uint256(amountDaiOut));
        console.log("New dai Balance: ", (checkBalance(makerDAI)) / (10**(18)));

        console.log("////Calculating dai debt including fee////");
        (, uint256 art) = vatContract.urns(ilk, urn);
        (,uint256 rate,,,) = vatContract.ilks(ilk);
        uint256 debt = (art*rate)/(10**(27)) + 1;
        console.log("Total Debt accrued: ", debt);
        console.log("Total Debt in new units: ", debt / (10**(18)));

        console.log("////Paying back Dai debt of: ", debt / (10**(18)), "////");
        console.log("Dai fees paid: ", (debt / (10**(18))) - (dart / (10**(18))));
        daiJoin.join(urn, debt);
        cdpContract.frob(cdp, -1*(int(dink)), -1*(int(dart)));
        console.log("New Dai balance: ", (checkBalance(makerDAI)) / (10**(18)));

        console.log("////Withdrawing Collateral. Current balance: ", (checkBalance(weth)) / (10**(18)), "////");
        cdpContract.flux(cdp, address(this), dink);
        mcdWeth.exit(address(this), dink);
        console.log("Collateral withdrawn. Current balance: ", (checkBalance(weth)) / (10**(18)));

    }

    function checkVault () 
    external view onlyOwner returns(uint256) {
        return vatContract.dai(urn);
    }
}