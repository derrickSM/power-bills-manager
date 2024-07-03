module power_bills::power_bills {
    use sui::sui::SUI;
    use std::string::String;
    use sui::coin::{Self, Coin};
    use sui::clock::{Self, Clock};
    use sui::balance::{Self, Balance};

    // Error definitions
    const EInsufficientBalance: u64 = 0;
    const EInvalidCustomer: u64 = 1;
    const EInvalidBill: u64 = 2;
    const ENotAuthorized: u64 = 3;

    // Struct definitions
    // Struct to represent contract capabilities
    public struct ContractCap has key, store {
        id: UID, // Unique identifier for the contractCap
        contract: address, // Address of the contract
        unit_price: u64, // Price per unit of power
        wallet: Balance<SUI>, // Balance of the contract
        overdue_fee: u64, // Fee for overdue bills
        min_date_overdue: u64, // Minimum date for overdue
        contract_duration: u64, // Duration of the contract in days
        late_fee_percentage: u64, // Late fee percentage for overdue bills
    }

    // Struct to represent a customer
    public struct Customer has key, store {
        id: UID, // Unique identifier for the customer
        user_code: String, // Code of the customer's bill meter
        wallet: Balance<SUI>, // Balance of SUI tokens
        bills: vector<Bill>, // Vector of bills for the customer
        units: u64, // Units of power consumed
        principal_address: address, // Principal address of the customer
        notifications: vector<Notification>, // Notifications for the customer
    }

    // Struct to represent a bill
    public struct Bill has key, store {
        id: UID, // Unique identifier for the bill
        customer_id: ID, // ID of the customer associated with the bill
        units: u64, // Units of power bought
        amount: u64, // Amount of the bill in SUI tokens
        due_date: u64, // Timestamp of the due date of the bill
        payment_status: bool, // Payment status of the bill
        breakdown: String, // Detailed breakdown of charges
    }

    // Struct to represent a notification
    public struct Notification has key, store {
        id: UID, // Unique identifier for the notification
        customer_id: ID, // ID of the customer associated with the notification
        message: String, // Notification message
        date: u64, // Date of the notification
    }

    // Functions for managing power bill payments
    // Initialize the contract
    public entry fun init(
        ctx: &mut TxContext
    ) {
        // Create a new contract object
        let contractCap = ContractCap {
            id: object::new(ctx),
            contract: tx_context::sender(ctx),
            unit_price: 10, // Price per unit of power
            overdue_fee: 5, // Fee for overdue bills
            wallet: balance::zero<SUI>(), // Initial balance of the contract
            min_date_overdue: 1000000, // Minimum timestamp date for overdue
            contract_duration: 365, // Contract duration of 1 year
            late_fee_percentage: 10, // Late fee percentage for overdue bills
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
    ) : Customer {
        let id = object::new(ctx); // Generate a new unique ID
        Customer {
            id,
            user_code,
            wallet: balance::zero<SUI>(),
            bills: vector::empty<Bill>(),
            units: 0,
            principal_address,
            notifications: vector::empty<Notification>(),
        }
    }

    // Function for customer to request units
    public entry fun request_units(
        customer: &mut Customer,
        contractCap: &ContractCap,
        units: u64,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        // Ensure the caller is the owner of the customer
        assert!(customer.principal_address == tx_context::sender(ctx), EInvalidCustomer);

        // Add the units to the customer
        customer.units = customer.units + units;

        // Calculate the amount
        let amount = units * contractCap.unit_price;

        // Generate a detailed breakdown of the charges
        let breakdown = format!("Units: {} x Unit Price: {} = {}", units, contractCap.unit_price, amount);

        // Generate a new bill
        let bill = Bill {
            id: object::new(ctx),
            customer_id: object::id(customer),
            units,
            amount,
            due_date: clock::timestamp_ms(clock) + contractCap.min_date_overdue, // Due date is 1 day from now
            payment_status: false, // Payment status is false
            breakdown,
        };

        // Add the bill to the customer
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

    // Function to pay bill directly
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

        // Calculate the amount
        let pay_amount = coin::value(&amount);

        // Check amount is greater than bill amount
        assert!(pay_amount >= bill.amount, EInsufficientBalance);

        // Transfer the bill amount from the customer to the contract
        let bill_amount = coin::into_balance(amount);
        balance::join(&mut contractCap.wallet, bill_amount);

        // Mark the bill as paid
        bill.payment_status = true;
    }

    // Function to update customer power usage
    public entry fun reduce_power_used(
        customer: &mut Customer,
        units: u64,
        ctx: &mut TxContext
    ) {
        // Ensure the caller is the owner of the customer
        assert!(customer.principal_address == tx_context::sender(ctx), EInvalidCustomer);

        // Subtract the units from the customer
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

        // Transfer the amount from the customer's wallet
        let withdraw_amount = coin::take(&mut customer.wallet, amount, ctx);
        transfer::public_transfer(withdraw_amount, customer.principal_address);
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
    ) : vector<ID> {
        let mut unpaid_bills = vector::empty<ID>();
        let len: u64 = vector::length(&customer.bills);

        let mut i = 0_u64;

        while (i < len) {
            let bill = &customer.bills[i];

            if (!bill.payment_status) {
                let id = object::uid_to_inner(&bill.id);
                unpaid_bills.push_back(id);
            };

            i = i + 1;
        };

        unpaid_bills
    }

    // Function for contract to charge late fees
    public entry fun apply_late_fees(
        customer: &mut Customer,
        contractCap: &ContractCap,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let len: u64 = vector::length(&customer.bills);

        let mut i = 0_u64;

        while (i < len) {
            let bill = &mut customer.bills[i];

            if ((!bill.payment_status) && (bill.due_date < clock::timestamp_ms(clock))) {
                let overdue_fee = contractCap.overdue_fee;
                let amount = bill.amount + overdue_fee;

                // Update the bill amount
                bill.amount = amount;

                // Send notification for overdue bill
                let notification = Notification {
                    id: object::new(ctx),
                    customer_id: object::id(customer),
                    message: format!("Your bill {} is overdue. An additional fee of {} SUI has been added.", bill.id, overdue_fee),
                    date: clock::timestamp_ms(clock),
                };

                // Add notification to the customer's notifications
                vector::push_back(&mut customer.notifications, notification);
            };

            i = i + 1;
        };
    }

    // Function to view notifications
    public fun view_notifications(
        customer: &Customer,
    ) : vector<Notification> {
        customer.notifications
    }

    // Function to renew contract
    public entry fun renew_contract(
        contractCap: &mut ContractCap,
        new_duration: u64,
        ctx: &mut TxContext
    ) {
        // Ensure the caller is the contract owner
        assert!(tx_context::sender(ctx) == contractCap.contract, ENotAuthorized);

        // Update contract duration
        contractCap.contract_duration = new_duration;

        // Send notification for contract renewal
        let notification = Notification {
            id: object::new(ctx),
            customer_id: contractCap.id,
            message: format!("Your contract has been renewed for {} days.", new_duration),
            date: clock::timestamp_ms(clock),
        };

        // Add notification to the contract's notifications
        vector::push_back(&mut contractCap.notifications, notification);
    }

    // Function to generate report for customer
    public fun generate_customer_report(
        customer: &Customer,
    ) : String {
        String::from_utf8(vector::concat(vec![
            String::to_utf8(customer.user_code.clone()),
            String::from_utf8(" - Units: ".to_utf8()),
            String::from_utf8(customer.units.to_string().to_utf8()),
            String::from_utf8(" - Balance: ".to_utf8()),
            String::from_utf8(balance::value(&customer.wallet).to_string().to_utf8()),
        ]))
    }

    // Function to generate report for bills
    public fun generate_bill_report(
        bill: &Bill,
    ) : String {
        String::from_utf8(vector::concat(vec![
            String::from_utf8("Bill ID: ".to_utf8()),
            String::to_utf8(bill.id.to_string()),
            String::from_utf8(" - Units: ".to_utf8()),
            String::to_utf8(bill.units.to_string()),
            String::from_utf8(" - Amount: ".to_utf8()),
            String::to_utf8(bill.amount.to_string()),
            String::from_utf8(" - Due Date: ".to_utf8()),
            String::to_utf8(bill.due_date.to_string()),
            String::from_utf8(" - Payment Status: ".to_utf8()),
            String::to_utf8(bill.payment_status.to_string()),
            String::from_utf8(" - Breakdown: ".to_utf8()),
            String::to_utf8(bill.breakdown.clone()),
        ]))
    }

    // Function to generate financial report for contract
    public fun generate_contract_financial_report(
        contractCap: &ContractCap,
    ) : String {
        String::from_utf8(vector::concat(vec![
            String::from_utf8("Contract Balance: ".to_utf8()),
            String::from_utf8(balance::value(&contractCap.wallet).to_string().to_utf8()),
            String::from_utf8(" - Overdue Fee: ".to_utf8()),
            String::from_utf8(contractCap.overdue_fee.to_string().to_utf8()),
        ]))
    }
}
