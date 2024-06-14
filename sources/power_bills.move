module power_bills::power_bills {
    use sui::sui::SUI;
    use std::string::String;
    use sui::coin::{Self, Coin};
    use sui::clock::{Self, Clock};
    use sui::balance::{Self, Balance};
    use sui::object;
    use sui::transfer;
    use sui::tx_context::TxContext;

    // Struct definitions
    // struct to represent contractCap
    public struct ContractCap has key, store {
        id: UID, // Unique identifier for the contractCap
        contract: address, // Address of the contract
        unit_price: u64, // Price per unit of power
        wallet: Balance<SUI>, // Balance of the contract
        overdue_fee: u64, // Fee for overdue bills (percentage)
        min_date_overdue: u64, // Minimum date for overdue
    }

    // Struct to represent a customer
    public struct Customer has key, store {
        id: UID, // Unique identifier for the customer
        user_code: String, // code of the customer bill meter
        wallet: Balance<SUI>, // Balance of SUI tokens
        bills: vector<Bill>, // Vector of bills for the customer
        units: u64, // Units of power consumed
        principal_address: address, // Principal address of the customer
    }

    // Struct to represent a bill
    public struct Bill has key, store {
        id: UID, // Unique identifier for the bill
        customer_id: ID, // ID of the customer associated with the bill
        units: u64, // Units of power bought
        amount: u64, // Amount of the bill in SUI tokens
        due_date: u64, // timestamp of Due date of the bill
        payment_status: bool, // Payment status of the bill
    }

    // Error definitions
    const EInsufficientBalance: u64 = 0;
    const EInvalidCustomer: u64 = 1;
    const EInvalidBill: u64 = 2;
    const ENotAuthorized: u64 = 3;
    const EOverdrawnUnits: u64 = 4;

    // Functions for managing power bill payments
    // initialize the contract
    public entry fun init(ctx: &mut TxContext) {
        // Create a new contract object
        let contractCap = ContractCap {
            id: object::new(ctx),
            contract: tx_context::sender(ctx),
            unit_price: 10, // Price per unit of power
            overdue_fee: 5, // Fee for overdue bills (percentage)
            wallet: balance::zero<SUI>(), // Initial balance of the contract
            min_date_overdue: 1000000, // Minimum timestamp date for overdue
        };

        let contractCap_address = tx_context::sender(ctx);
        
        // Transfer the contract object to the contract owner
        transfer::transfer(contractCap, contractCap_address);
    }

    // Function to register a new customer
    public entry fun register_customer(
        user_code: String,
        principal_address: address,
        ctx: &mut TxContext
    ) {
        assert!(tx_context::sender(ctx) == contractCap.contract, ENotAuthorized);

        let id = object::new(ctx); // Generate a new unique ID
        let customer = Customer {
            id,
            user_code,
            wallet: balance::zero<SUI>(),
            bills: vector::empty<Bill>(),
            units: 0,
            principal_address,
        };

        // Transfer the customer object to the principal address
        transfer::transfer(customer, principal_address);
    }

    // function for customer to request units
    public entry fun request_units(
        customer: &mut Customer,
        contractCap: &ContractCap,
        units: u64,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        // Ensure the caller is the owner of the customer
        assert!(customer.principal_address == tx_context::sender(ctx), EInvalidCustomer);

        // add the units to the customer
        customer.units = customer.units + units;

        // calculate the amount
        let amount = units * contractCap.unit_price;

        // generate a new bill
        let bill = Bill {
            id: object::new(ctx),
            customer_id: object::id(customer),
            units,
            amount,
            due_date: clock::timestamp_ms(clock) + contractCap.min_date_overdue, // Due date is based on min_date_overdue
            payment_status: false, // Payment status is false
        };

        // add the bill to the customer
        vector::push_back(&mut customer.bills, bill);
    }

    // Function to deposit funds into a customer's wallet
    public entry fun deposit(
        customer: &mut Customer,
        amount: Coin<SUI>,
        ctx: &mut TxContext
    ) {
        // Ensure the caller is the customer
        assert!(customer.principal_address == tx_context::sender(ctx), EInvalidCustomer);

        let coin = coin::into_balance(amount);
        balance::join(&mut customer.wallet, coin);
    }

    // Function to pay a bill
    public entry fun pay_bill_from_wallet(
        customer: &mut Customer,
        contractCap: &mut ContractCap,
        bill: &mut Bill,
        ctx: &mut TxContext
    ) {
        // Ensure the caller is the customer
        assert!(customer.principal_address == tx_context::sender(ctx), EInvalidCustomer);
        // Ensure the bill is valid
        assert!(bill.customer_id == object::id(customer), EInvalidBill);
        // Ensure the bill is unpaid
        assert!(!bill.payment_status, EInvalidBill);

        // Ensure the customer has sufficient wallet balance
        assert!(balance::value(&customer.wallet) >= bill.amount, EInsufficientBalance);

        // Transfer the bill amount from the customer to the contract
        let bill_amount = coin::take(&mut customer.wallet, bill.amount, ctx);
        transfer::public_transfer(bill_amount, contractCap.contract);

        // Mark the bill as paid
        bill.payment_status = true;
    }

    // pay bill directly
    public entry fun pay_bill_directly(
        customer: &mut Customer,
        contractCap: &mut ContractCap,
        bill: &mut Bill,
        amount: Coin<SUI>,
        ctx: &mut TxContext
    ) {
        // Ensure the caller is the owner of the customer
        assert!(customer.principal_address == tx_context::sender(ctx), EInvalidCustomer);
        // Ensure the bill is valid
        assert!(bill.customer_id == object::id(customer), EInvalidBill);
        // Ensure the bill is unpaid
        assert!(!bill.payment_status, EInvalidBill);

        // calculate the amount
        let pay_amount = coin::value(&amount);

        // check amount is greater than bill amount
        assert!(pay_amount >= bill.amount, EInsufficientBalance);

        // Transfer the bill amount from the customer to the contract
        let bill_amount = coin::into_balance(amount);
        balance::join(&mut contractCap.wallet, bill_amount);

        // Mark the bill as paid
        bill.payment_status = true;
    }

    // update customer power usage
    public entry fun reduce_power_used(
        customer: &mut Customer,
        units: u64,
        ctx: &mut TxContext
    ) {
        // Ensure the caller is the owner of the customer
        assert!(customer.principal_address == tx_context::sender(ctx), EInvalidCustomer);
        // Ensure the customer has sufficient units
        assert!(customer.units >= units, EOverdrawnUnits);

        // reduce the units for the customer
        customer.units = customer.units - units;
    }

    // Function to withdraw funds from a customer's wallet
    public entry fun withdraw(
        customer: &mut Customer,
        amount: u64,
        ctx: &mut TxContext
    ) {
        // Ensure the caller is the owner of the customer
        assert!(customer.principal_address == tx_context::sender(ctx), ENotAuthorized);

        // Ensure the customer has sufficient balance
        assert!(balance::value(&customer.wallet) >= amount, EInsufficientBalance);

        // Ensure the customer has no outstanding bills
        for bill in &customer.bills {
            assert!(bill.payment_status, EInsufficientBalance);
        }

        // Transfer the amount from the customer's wallet
        let withdraw_amount = coin::take(&mut customer.wallet, amount, ctx);
        transfer::public_transfer(withdraw_amount, customer.principal_address);
    }

    // function for customer to view remaining units
    public fun view_remaining_units(
        customer: &Customer,
    ) : u64 {
        customer.units
    }

    // function for customer to view unpaid bills
    public fun view_unpaid_bills(
        customer: &Customer,
    ) : vector<ID> {
        let unpaid_bills = customer.bills.iter().filter(|bill| !bill.payment_status).map(|bill| object::uid_to_inner(&bill.id)).collect();
        unpaid_bills
    }

    // function for contract to charge late fees
    public entry fun apply_late_fees(
        customer: &mut Customer,
        contractCap: &ContractCap,
        clock: &Clock,
        _ctx: &mut TxContext
    ) {
        let max_fee = 100; // Maximum late fee in SUI tokens or percentage
        for bill in &mut customer.bills {
            if !bill.payment_status && bill.due_date < clock::timestamp_ms(clock) {
                let overdue_fee = bill.amount * contractCap.overdue_fee / 100;
                let final_fee = if overdue_fee > max_fee {
                    max_fee
                } else {
                    overdue_fee
                };
                bill.amount += final_fee;
            }
        }
    }
}
