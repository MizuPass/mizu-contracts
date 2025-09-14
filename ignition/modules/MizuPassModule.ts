import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

export default buildModule("MizuPassModule", (m) => {
  const mizuPassIdentity = m.contract("MizuPassIdentity");
  const stealthAddressManager = m.contract("StealthAddressManager");
  
  const mockJPYM = m.contract("MockJPYM");
  
  const eventRegistry = m.contract("EventRegistry", [
    mizuPassIdentity
  ]);
  
  m.call(eventRegistry, "setJPYMAddress", [mockJPYM]);
  
  m.call(eventRegistry, "setPlatformWallet", ['0xfd1AF2826012385a84A8E9BE8a1586293FB3980B']);
  
  return {
    mizuPassIdentity,
    stealthAddressManager,
    mockJPYM,
    eventRegistry
  };
});
