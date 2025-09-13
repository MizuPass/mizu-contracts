import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

export default buildModule("mizupassModule", (m) => {
  const mizuPassIdentity = m.contract("MizuPassIdentity");
  
  const stealthAddressManager = m.contract("StealthAddressManager", [
    mizuPassIdentity
  ]);
  
  const mizuPassPaymentGateway = m.contract("MizuPassPaymentGateway", [
    mizuPassIdentity,
    stealthAddressManager
  ]);
  
  const eventRegistry = m.contract("EventRegistry", [
    mizuPassIdentity
  ]);
  
  m.call(eventRegistry, "setPaymentGateway", [mizuPassPaymentGateway]);
    
  return {
    mizuPassIdentity,
    stealthAddressManager,
    mizuPassPaymentGateway,
    eventRegistry
  };
});
