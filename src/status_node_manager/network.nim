import
  # Nimble packages
  confutils/std/net

const
  defaultSNMRestPort* = 13000
  defaultSNMRestPortDesc* = $defaultSNMRestPort

  defaultAdminListenAddress* = (static parseIpAddress("127.0.0.1"))
  defaultAdminListenAddressDesc* = $defaultAdminListenAddress

