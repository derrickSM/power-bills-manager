module power_bills::power_bills {
    use sui::sui::SUI;
    use std::string::String;
    use sui::coin::{Self, Coin};
    use sui::clock::{Self, Clock};
    use sui::balance::{Self, Balance};
    use sui::table::{Self, Table};

    // Struct definitions
    // struct to represent contractCap
    public struct Contract has key, store {
        id: UID, // Unique identifier for the contractCap
        contract: address, // Address of the contract
        unit_price: u64, // Price per unit of power
        bills: Table<address, Bill>,
        wallet: Balance<SUI>, // Balance of the contract
        overdue_fee: u64, // Fee for overdue bills
        min_date_overdue: u64, // Minimum date for overdue
    }

    public struct ContractCap has key {
        id: UID,
        to: ID
    }

    // Struct to represent a customer
    public struct Customer has key, store {
        id: UID, // Unique identifier for the customer
        user_code: String, // code of the customer bill meter
        wallet: Balance<SUI>, // Balance of SUI tokens
        units: u64, // Units of power consumed
        principal_address: address, // Principal address of the customer
    }

    // Struct to represent a bill
    public struct Bill has copy, drop, store {
        customer_id: ID, // ID of the customer associated with the bill
        units: u64, // Units of power bought
        amount: u64, // Amount of the bill in SUI tokens
        due_date: u64, // timestamp of Due date of the bill
        payment_status: bool, // Payment status of the bill
    }

    // Error definitions
    const EInsufficientBallance: u64 = 0;
    const EInvalidCustomer: u64 = 1;
    const EInvalidBill: u64 = 2;
    const ENotAuthorized: u64 = 3;

    // Functions for managing power bill payments
    // initialize the contract
    fun init(
        ctx: &mut TxContext
    ) {
        let id_ = object::new(ctx);
        let inner_ = object::uid_to_inner(&id_);
        // Create a new contract object
        transfer::share_object(Contract {
            id: id_,
            contract: tx_context::sender(ctx),
            unit_price: 10, // Price per unit of power
            bills: table::new(ctx),
            overdue_fee: 5, // Fee for overdue bills
            wallet: balance::zero<SUI>(), // Initial balance of the contract
            min_date_overdue: 1000000, // Minimum timestamp date for overdue
        });
        let cap = ContractCap {
            id: object::new(ctx),
            to: inner_
        };
        transfer::transfer(cap, ctx.sender());
    }

    // Function to register a new customer
    public fun register_customer(
        user_code: String,
        principal_address: address,
        ctx: &mut TxContext
    ) : Customer {
        let id = object::new(ctx); // Generate a new unique ID
        Customer {
            id,
            user_code,
            wallet: balance::zero<SUI>(),
            units: 0,
            principal_address,
        }
    }

    // function for customer to request units
    public fun request_units(
        customer: &mut Customer,
        self: &mut Contract,
        units: u64,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        // add the units to the customer
        customer.units = customer.units + units;
        // calculate the amount
        let amount = units * self.unit_price;
        // generate a new bill
        let bill = Bill {
            customer_id: object::id(customer),
            units,
            amount,
            due_date: clock::timestamp_ms(clock) + self.min_date_overdue, // Due date is 1 day from now
            payment_status: false, // Payment status is false
        };
        // add the bill to the customer
        table::add(&mut self.bills, ctx.sender(), bill);
    }

    // Function to deposit funds into a customer's wallet
    public fun deposit(
        customer: &mut Customer,
        amount: Coin<SUI>,
        ctx: &mut TxContext
    ) {
        coin::put(&mut customer.wallet, amount);
    }

    // Function to pay a bill
    public fun pay_bill(
        customer: &mut Customer,
        self: &mut Contract,
        ctx: &mut TxContext
    ) {
        let bill = table::remove(&mut self.bills, ctx.sender());
        // Transfer the bill amount from the customer to the contract
        let bill_amount = coin::take(&mut customer.wallet, (bill.amount), ctx);
        coin::put(&mut self.wallet, bill_amount);
    }

    // update customer power usage
    public fun reduce_power_used(
        customer: &mut Customer,
        units: u64,
        ctx: &mut TxContext
    ) {
        // Ensure the caller is the owner of the customer
        assert!(customer.principal_address == tx_context::sender(ctx), EInvalidCustomer);
        // add the units to the customer
        customer.units = customer.units - units;
    }

    // Function to withdraw funds from a customer's wallet
    public fun withdraw(
        customer: &mut Customer,
        amount: u64,
        ctx: &mut TxContext
    ) : Coin<SUI> {
        let coin = coin::take(&mut customer.wallet, amount, ctx);
        coin 
    }

    // function for customer to view remaining units
    public fun view_remaining_units(
        customer: &Customer,
    ) : u64 {
        customer.units
    }
}
