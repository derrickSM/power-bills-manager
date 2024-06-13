# Power Bills Sui Module

This module implements a power bill management system on the Sui blockchain. It allows customers to register, request power units, pay bills, and view their usage and billing information. The contract also facilitates late fee application for overdue bills.

**Key Features:**

* **Customer Registration:** Users can register as customers, providing their code and principal address.
* **Unit Requests:** Customers can request power units, with the corresponding bill amount automatically calculated.
* **Bill Payments:** Customers can pay bills using funds deposited in their wallet or directly transferring SUI tokens.
* **Wallet Management:** Customers can deposit and withdraw funds from their wallet within the contract.
* **Power Usage Update:** Customers can update their power usage after consumption (for informational purposes).
* **Unpaid Bill View:** Customers can view a list of their unpaid bills.
* **Late Fee Application:** The contract automatically applies late fees to unpaid bills after the due date.

**Data Structures:**

* **ContractCap:** Represents the overall power bill contract with:
  * `id`: Unique identifier for the contract.
  * `contract`: Address of the contract.
  * `unit_price`: Price per unit of power.
  * `wallet`: Balance of SUI tokens held by the contract.
  * `overdue_fee`: Late fee charged for overdue bills.
  * `min_date_overdue`: Minimum timestamp for a bill to be considered overdue (in milliseconds).
* **Customer:** Represents a registered customer with:
  * `id`: Unique identifier for the customer.
  * `user_code`: Code associated with the customer's power meter.
  * `wallet`: Balance of SUI tokens within the contract.
  * `bills`: Vector of bills associated with the customer.
  * `units`: Current power units used by the customer.
  * `principal_address`: Sui address of the customer.
* **Bill:** Represents a power bill with:
  * `id`: Unique identifier for the bill.
  * `customer_id`: ID of the customer associated with the bill.
  * `units`: Number of power units purchased.
  * `amount`: Total SUI amount due for the bill.
  * `due_date`: Timestamp of the bill's due date (in milliseconds).
  * `payment_status`: Boolean indicating whether the bill is paid (true) or unpaid (false).

**Error Codes:**

* `EInsufficientBallance (0)`: Indicates the customer has insufficient funds in their wallet.
* `EInvalidCustomer (1)`: Indicates an invalid customer object or unauthorized access.
* `EInvalidBill (2)`: Indicates an invalid bill object or attempting to pay an already paid bill.
* `ENotAuthorized (3)`: Indicates unauthorized attempt to perform an action (e.g., withdrawal by a non-owner).

**Functions:**

* **init (ctx: &mut TxContext):** Initializes a new power bills contract setting the unit price, overdue fee, and minimum overdue date.
* **register_customer (user_code: String, principal_address: address, ctx: &mut TxContext): Customer:** Registers a new customer and returns their details.
* **request_units (customer: &mut Customer, contractCap: &ContractCap, units: u64, clock: &Clock, ctx: &mut TxContext):** Allows a customer to request power units, generating a corresponding bill.
* **deposit (customer: &mut Customer, amount: Coin<SUI>, ctx: &mut TxContext):** Allows a customer to deposit SUI tokens to their wallet within the contract.
* **pay_bill_from_wallet (customer: &mut Customer, contractCap: &mut ContractCap, bill: &mut Bill, ctx: &mut TxContext):** Allows a customer to pay a bill using funds from their wallet.
* **pay_bill_directly (customer: &mut Customer, contractCap: &mut ContractCap, bill: &mut Bill, amount: Coin<SUI>, ctx: &mut TxContext):** Allows a customer to directly pay a bill using SUI tokens (without using their wallet).
* **reduce_power_used (customer: &mut Customer, units: u64, ctx: &mut TxContext):** Allows a customer to update their power usage after consumption (for informational purposes).
* **withdraw (customer: &mut Customer, amount: u64, ctx: &mut TxContext):** Allows a customer to withdraw SUI tokens from their wallet within the contract.
* **view_remaining_units (customer: &Customer): u64:** Allows a customer to view their remaining power units.
* **view_unpaid_bills (customer: &Customer): vector<ID>:** Allows a customer to view a list of their unpaid bill IDs.
* **apply_late_fees (customer: &mut Customer, contractCap: &ContractCap, clock: &Clock, _ctx: &mut TxContext):** This function automatically iterates through the customer's bills and applies late fees to any unpaid bills that have passed the due date.

**Security Considerations:**

* Access control mechanisms are implemented using `customer.principal_address` to ensure only authorized users can perform actions on their customer objects and wallets.
* Error handling is included to prevent unauthorized access, insufficient funds, and invalid bill operations.

**Dependencies:**

* This module requires the `sui` and `candid` crates for Sui blockchain interaction and data serialization.
* It also utilizes the `clock` module for timestamp retrieval.

## Dependencies installation

1. Install dependencies by running the following commands:

   * `sudo apt update`

   * `sudo apt install curl git-all cmake gcc libssl-dev pkg-config libclang-dev libpq-dev build-essential -y`

2. Install Rust and Cargo

   * `curl https://sh.rustup.rs -sSf | sh`

   * source "$HOME/.cargo/env"

3. Install Sui Binaries

   * run the command `chmod u+x sui-binaries.sh` to make the file an executable

   execute the installation file by running

   * `./sui-binaries.sh "v1.21.0" "devnet" "ubuntu-x86_64"` for Debian/Ubuntu Linux users

   * `./sui-binaries.sh "v1.21.0" "devnet" "macos-x86_64"` for Mac OS users with Intel based CPUs

   * `./sui-binaries.sh "v1.21.0" "devnet" "macos-arm64"` for Silicon based Mac

## Installation

1. Clone the repo

   ```sh
   git clone https://github.com/kututajohn/de-collector
   ```

2. Navigate to the working directory

   ```sh
   cd de-collector
   ```

## Run a local network

To run a local network with a pre-built binary (recommended way), run this command:

```
RUST_LOG="off,sui_node=info" sui-test-validator
```

## Configure connectivity to a local node

Once the local node is running (using `sui-test-validator`), you should the url of a local node - `http://127.0.0.1:9000` (or similar).
Also, another url in the output is the url of a local faucet - `http://127.0.0.1:9123`.

Next, we need to configure a local node. To initiate the configuration process, run this command in the terminal:

```
sui client active-address
```

The prompt should tell you that there is no configuration found:

```
Config file ["/home/codespace/.sui/sui_config/client.yaml"] doesn't exist, do you want to connect to a Sui Full node server [y/N]?
```

Type `y` and in the following prompts provide a full node url `http://127.0.0.1:9000` and a name for the config, for example, `localnet`.

On the last prompt you will be asked which key scheme to use, just pick the first one (`0` for `ed25519`).

After this, you should see the ouput with the wallet address and a mnemonic phrase to recover this wallet. You can save so later you can import this wallet into SUI Wallet.

Additionally, you can create more addresses and to do so, follow the next section - `Create addresses`.

### Create addresses

For this tutorial we need two separate addresses. To create an address run this command in the terminal:

```
sui client new-address ed25519
```

where:

* `ed25519` is the key scheme (other available options are: `ed25519`, `secp256k1`, `secp256r1`)

And the output should be similar to this:

```
╭─────────────────────────────────────────────────────────────────────────────────────────────────╮
│ Created new keypair and saved it to keystore.                                                   │
├────────────────┬────────────────────────────────────────────────────────────────────────────────┤
│ address        │ 0x05db1e318f1e4bc19eb3f2fa407b3ebe1e7c3cd8147665aacf2595201f731519             │
│ keyScheme      │ ed25519                                                                        │
│ recoveryPhrase │ lava perfect chef million beef mean drama guide achieve garden umbrella second │
╰────────────────┴────────────────────────────────────────────────────────────────────────────────╯
```

Use `recoveryPhrase` words to import the address to the wallet app.

### Get localnet SUI tokens

```
curl --location --request POST 'http://127.0.0.1:9123/gas' --header 'Content-Type: application/json' \
--data-raw '{
    "FixedAmountRequest": {
        "recipient": "<ADDRESS>"
    }
}'
```

`<ADDRESS>` - replace this by the output of this command that returns the active address:

```
sui client active-address
```

You can switch to another address by running this command:

```
sui client switch --address <ADDRESS>
```

## Build and publish a smart contract

### Build package

To build tha package, you should run this command:

```
sui move build
```

If the package is built successfully, the next step is to publish the package:

### Publish package

```
sui client publish --gas-budget 100000000 --json
` - `sui client publish --gas-budget 1000000000`
```
