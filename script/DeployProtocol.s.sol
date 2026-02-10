// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";

import "contracts/Escrow.sol";
import "contracts/VehicleRegistry.sol";
import "contracts/CarShareCore.sol";
import "contracts/VehicleSaleCore.sol";

contract DeployProtocol is Script {
  function run() external {
    uint256 deployerKey = vm.envUint("DEPLOYER_KEY");

    address protocolTreasury = vm.envAddress("PROTOCOL_TREASURY");
    uint16  protocolBps      = uint16(vm.envUint("PROTOCOL_FEE_BPS")); // for example 50 (0.5%)

    vm.startBroadcast(deployerKey);

    Escrow escrow = new Escrow();
    VehicleRegistry registry = new VehicleRegistry("KEY Vehicle Registry", "KEYVEH");
    CarShareCore rentCore = new CarShareCore(address(escrow), protocolTreasury, protocolBps);
    VehicleSaleCore saleCore = new VehicleSaleCore(address(escrow), protocolTreasury, protocolBps);

    // wire cores to escrow
    escrow.setCore(address(rentCore), true);
    escrow.setCore(address(saleCore), true);

    vm.stopBroadcast();

    registry;
  }
}
