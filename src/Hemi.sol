// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IL2Tunnel {
     function bridgeERC20To(
        address _localToken,
        address _remoteToken,
        address _to,
        uint256 _amount,
        uint32 _minGasLimit,
        bytes calldata _extraData
    ) external;
}

contract Hemi is ERC20, Ownable {
    uint256 public constant MINTAGE_PERIOD = 30 days;
    uint256 public constant ANNUAL_INFLATION_RATE = 700; // 7% annual inflation
    uint32 public constant l2TunnelMinGasLimit = 400000;

    uint256 public lastEmission;

    // ### Tunnel config
    address public l2Tunnel;
    address public l2Destination;
    address public remoteToken;
    

    // ####### Events #######
    event EmissionsEnabled(uint256 timestamp);
    event EmissionsSetup(address indexed l2Tunnel, address indexed l2Destination, address indexed remoteToken);
    event EmissionsMinted(uint256 emissionAmount, uint256 timestamp);

    error EmissionsAlreadyEnabled();
    error EmissionsNotEnabled();
    error EmissionNotSetup();
    error NullAddress();
    error EmissionAmountZero();
    error MintagePeriodNotElapsed();

    constructor(address _owner , address _initialMintReceiver) ERC20("hemi", "HEMI") Ownable(_owner) {
        // Mint initial supply to the owner
        _mint(_initialMintReceiver, 10e9 * 10 ** decimals()); // 10B tokens
    }

    /**
     * @notice Calculates the emission amount based on the time elapsed since the last emission.
     * @return _emissionAmount The calculated emission amount.
     */
    function calculateEmission() public view returns (uint256 _emissionAmount) {
        if (lastEmission == 0) {
            return 0;
        }
        uint256 _timeElapsed = block.timestamp - lastEmission;
        _emissionAmount = (totalSupply() * ANNUAL_INFLATION_RATE * _timeElapsed) / (365 days * 10000);
    }

    /**
     * @notice Mints emissions based on the calculated emission amount.
    */
    function mintEmissions() external {
        uint256 _lastEmission = lastEmission;
        if (_lastEmission == 0) {
            revert EmissionsNotEnabled();
        }
        uint256 _timeElapsed = block.timestamp - _lastEmission;
        if (_timeElapsed < MINTAGE_PERIOD) {
            revert MintagePeriodNotElapsed();
        }

        uint256 _emissionAmount = calculateEmission();
        if (_emissionAmount == 0) {
            revert EmissionAmountZero();
        }
        lastEmission = block.timestamp;
        
        _mint(address(this), _emissionAmount);
        _approve(address(this), l2Tunnel, _emissionAmount);
        IL2Tunnel(l2Tunnel).bridgeERC20To(
            address(this),
            remoteToken,
            l2Destination,
            _emissionAmount,
            l2TunnelMinGasLimit,
            ""
        );

        // Emit event for minting emissions
        emit EmissionsMinted(_emissionAmount, block.timestamp);
    }

    // ####### Owner only functions #####

    /**
     * @notice Enables emissions by setting the `lastEmission` timestamp.
    */
    function enableEmissions() external onlyOwner {
        if (lastEmission != 0) {
            revert EmissionsAlreadyEnabled();
        }
        if (l2Tunnel == address(0) || l2Destination == address(0)) {
            revert EmissionNotSetup();
        }
        lastEmission = block.timestamp;
        emit EmissionsEnabled(block.timestamp);
    }

    /**
     * @notice Sets up the emissions by specifying the L2 tunnel and destination addresses.
     * owner can update multiple times as long as emission not enabled
     * @param l2Tunnel_ The address of the L2 tunnel.
     * @param l2Destination_ The address of the L2 destination.
    */
    function setupEmissions(address l2Tunnel_, address l2Destination_, address remoteToken_) external onlyOwner {
        if (lastEmission != 0) {
            revert EmissionsAlreadyEnabled();
        }
        if (l2Tunnel_ == address(0) || l2Destination_ == address(0) || remoteToken_ == address(0)) {
            revert NullAddress();
        }

        l2Tunnel = l2Tunnel_;
        l2Destination = l2Destination_;
        remoteToken = remoteToken_;

        emit EmissionsSetup(l2Tunnel_, l2Destination_, remoteToken_);
    }
}