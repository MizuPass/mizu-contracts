import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

export default buildModule("MizuPassModule", (m) => {
  const mizuPassIdentity = m.contract("MizuPassIdentity");
  const stealthAddressManager = m.contract("StealthAddressManager");
  const mizuPassPaymentGateway = m.contract("MizuPassPaymentGateway", [
    mizuPassIdentity,
    stealthAddressManager
  ]);
  
  const eventRegistry = m.contract("EventRegistry", [
    mizuPassIdentity
  ]);
  
  m.call(eventRegistry, "setPaymentGateway", [mizuPassPaymentGateway]);
  m.call(eventRegistry, "setPlatformWallet", ['0xfd1AF2826012385a84A8E9BE8a1586293FB3980B']);
  
  return {
    mizuPassIdentity,
    stealthAddressManager,
    mizuPassPaymentGateway,
    eventRegistry
  };
});
