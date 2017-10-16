module.exports = {
  networks: {
    development: {
      host: "localhost",
      port: 8545,
      gasPrice: 22000000000, // Specified in Wei
      network_id: "*" // Match any network id
    }  
  }
};
