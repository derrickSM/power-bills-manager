module power_bills::power_bills {
    use sui::sui::SUI;
    use std::string::String;
    use sui::coin::{Coin};
    use sui::clock::{Clock};
    use sui::balance::{Balance};
    use sui::event::{Event, EmitEvent};
    use sui::tx_context::{Self, TxContext};

    // Event definitions for logging
    public event NewCustomer(address::Address, String);
    public event BillPayment(address::Address, u64);
    public event LateFeeApplied(address::Address, u64);

    // Struct definitions
    public struct ContractCap has key, store {
        id: UID, // Unique identifier for the contractCap
        contract: address::Address, // Address of the contract
        unit_price: u64, // Price per unit of power
        wallet: Balance<SUI>, // Balance of the contract
        overdue_fee: u64, // Fee for overdue bills
        min_date_overdue: u64, // Minimum date for overdue
    }

    public struct Customer has key, store {
        id: UID, // Unique identifier for the customer
        user_code: String, // Code of the customer bill meter
        wallet: Balance<SUI>, // Balance of SUI tokens
        bills: vector<Bill>, // Vector of bills for the customer
        units: u64, // Units of power consumed
        principal_address: address::Address, // Principal address of the customer
    }

    public struct Bill has key, store {
        id: UID, // Unique identifier for the bill
        customer_id: UID, // ID of the customer associated with the bill
        units: u64, // Units of power bought
        amount: u64, // Amount of the bill in SUI tokens
        due_date: u64, // Timestamp of Due date of the bill
        payment_status: bool, // Payment status of the bill
    }

    // Error definitions
    const EInsufficientBalance: u64 = 0;
    const EInvalidCustomer: u64 = 1;
    const EInvalidBill: u64 = 2;
    const ENotAuthorized: u64 = 3;

    // Functions for managing power bill payments

    // Initialize the contract
    fun init(
        ctx: &mut TxContext
    ) {
        // Create a new contract object
        let contractCap = ContractCap {
            id: object::new(ctx),
            contract: tx_context::sender_addr(ctx),
            unit_price: 10, // Price per unit of power
            overdue_fee: 5, // Fee for overdue bills
            wallet: balance::zero<SUI>(), // Initial balance of the contract
            min_date_overdue: 1000000, // Minimum timestamp date for overdue
        };

        let contractCap_address = tx_context::sender_addr(ctx);
        
        // Transfer the contract object to the contract owner
        move_to(contractCap_address, contractCap);
    }

    // Function to register a new customer
    public fun register_customer(
        user_code: String,
        principal_address: address::Address,
        ctx: &mut TxContext
    ) : Customer {
        let id = object::new(ctx);
        let customer = Customer {
            id,
            user_code,
            wallet: balance::zero<SUI>(),
            bills: vector::empty<Bill>(),
            units: 0,
            principal_address,
        };

        // Emit a NewCustomer event
        emit!(NewCustomer(customer.principal_address, customer.user_code));

        customer
    }

    // Function for customer to request units
    public fun request_units(
        customer: &mut Customer,
        contractCap: &mut ContractCap,
        units: u64,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        // Ensure the caller is the owner of the customer
        assert!(customer.principal_address == tx_context::sender_addr(ctx), EInvalidCustomer);

        // Add the units to the customer
        customer.units = customer.units + units;

        // Calculate the amount
        let amount = units * contractCap.unit_price;

        // Generate a new bill
        let bill = Bill {
            id: object::new(ctx),
            customer_id: object::id(customer),
            units,
            amount,
            due_date: clock::timestamp_ms(clock) + contractCap.min_date_overdue,
            payment_status: false,
        };

        // Add the bill to the customer
        vector::push_back(&mut customer.bills, bill);
    }

    // Function to deposit funds into a customer's wallet
    public fun deposit(
        customer: &mut Customer,
        amount: Coin<SUI>,
        ctx: &mut TxContext
    ) {
        // Ensure the caller is the customer
        assert!(customer.principal_address == tx_context::sender_addr(ctx), EInvalidCustomer);

        let coin = coin::into_balance(amount);
        balance::join(&mut customer.wallet, coin);
    }

    // Function to pay a bill from wallet
    public fun pay_bill_from_wallet(
        customer: &mut Customer,
        contractCap: &mut ContractCap,
        bill: &mut Bill,
        ctx: &mut TxContext
    ) {
        // Ensure the caller is the customer
        assert!(customer.principal_address == tx_context::sender_addr(ctx), EInvalidCustomer);
        // Ensure the bill is valid
        assert!(bill.customer_id == object::id(customer), EInvalidBill);
        // Ensure the bill is unpaid
        assert!(!bill.payment_status, EInvalidBill);

        // Ensure the customer has sufficient wallet balance
        assert!(balance::value(&customer.wallet) >= bill.amount, EInsufficientBalance);

        // Transfer the bill amount from the customer to the contract
        let bill_amount = coin::take(&mut customer.wallet, bill.amount, ctx);
        balance::join(&mut contractCap.wallet, bill_amount);

        // Mark the bill as paid
        bill.payment_status = true;

        // Emit a BillPayment event
        emit!(BillPayment(customer.principal_address, bill.amount));
    }

    // Function to pay a bill directly
    public fun pay_bill_directly(
        customer: &mut Customer,
        contractCap: &mut ContractCap,
        bill: &mut Bill,
        amount: Coin<SUI>,
        ctx: &mut TxContext
    ) {
        // Ensure the caller is the owner of the customer
        assert!(customer.principal_address == tx_context::sender_addr(ctx), EInvalidCustomer);
        // Ensure the bill is valid
        assert!(bill.customer_id == object::id(customer), EInvalidBill);
        // Ensure the bill is unpaid
        assert!(!bill.payment_status, EInvalidBill);

        // Calculate the amount
        let pay_amount = coin::value(&amount);

        // Check if the amount is greater than or equal to bill amount
        assert!(pay_amount >= bill.amount, EInsufficientBalance);

        // Transfer the bill amount from the customer to the contract
        let bill_amount = coin::into_balance(amount);
        balance::join(&mut contractCap.wallet, bill_amount);

        // Mark the bill as paid
        bill.payment_status = true;

        // Emit a BillPayment event
        emit!(BillPayment(customer.principal_address, bill.amount));
    }

    // Function to update customer power usage
    public fun reduce_power_used(
        customer: &mut Customer,
        units: u64,
        ctx: &mut TxContext
    ) {
        // Ensure the caller is the owner of the customer
        assert!(customer.principal_address == tx_context::sender_addr(ctx), EInvalidCustomer);

        // Ensure non-negative units after reduction
        assert!(customer.units >= units, EInvalidBill);

        // Reduce the units of the customer
        customer.units = customer.units - units;
    }

    // Function to withdraw funds from a customer's wallet
    public fun withdraw(
        customer: &mut Customer,
        amount: u64,
        ctx: &mut TxContext
    ) {
        // Ensure the caller is the owner of the customer
        assert!(customer.principal_address == tx_context::sender_addr(ctx), ENotAuthorized);

        // Ensure the customer has sufficient balance
        assert!(balance::value(&customer.wallet) >= amount, EInsufficientBalance);

        // Transfer the amount from the customer's wallet
        let withdraw_amount = coin::take(&mut customer.wallet, amount, ctx);
        move_to(customer.principal_address, withdraw_amount);
    }

    // Function for customer to view remaining units
    public fun view_remaining_units(
        customer: &Customer,
    ) : u64 {
        customer.units
    }

    // Function for customer to view unpaid bills
    public fun view_unpaid_bills(
        customer: &Customer,
    ) : vector<UID> {
        let mut unpaid_bills = vector::empty<UID>();
        let len: u64 = vector::length(&customer.bills);

        let mut i = 0_u64;

        while (i < len) {
            let bill = &customer.bills[i];

            if (!bill.payment_status) {
                let id = bill.id;
                vector::push_back(&mut unpaid_bills, id);
            };

            i = i + 1;
        };

        unpaid_bills
    }

    // Function for contract to charge late fees
    public fun apply_late_fees(
        customer: &mut Customer,
        contractCap: &mut ContractCap,
        clock: &Clock
    ) {
        let len: u64 = vector::length(&customer.bills);
        let mut i = 0_u64;

        while (i < len) {
            let bill = &mut customer.bills[i];

            if (!bill.payment_status && bill.due_date < clock::timestamp_ms(clock)) {
                let overdue_fee = contractCap.overdue_fee;
                let amount = bill.amount + overdue_fee;

                // Update the bill amount
                bill.amount = amount;

                // Emit a LateFeeApplied event
                emit!(LateFeeApplied(customer.principal_address, overdue_fee));
            }

            i = i + 1;
        }
    }
}
