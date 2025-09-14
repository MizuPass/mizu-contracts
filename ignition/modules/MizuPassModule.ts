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
  m.call(eventRegistry, "setPlatformWallet", [m.getAccount(0)]);
  
  return {
    mizuPassIdentity,
    stealthAddressManager,
    mizuPassPaymentGateway,
    eventRegistry
  };
});
