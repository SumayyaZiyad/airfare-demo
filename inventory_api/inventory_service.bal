import ballerina/log;
import ballerina/http;
import aneesha/fares_api;

public type SeatAllocation record {|
    string flightNumber;
    string flightDate;
    int seats;
    Personnel owner?;
|};

public type Flight record {
    readonly string flightNumber;
    readonly string flightDate;
    int available;
    int totalCapacity;
};

public type FareFlight record {
    fares_api:Fare fare;
    Flight flight;
};

public type Personnel record {
    string name;
    int id;
    int contact;
};

@display {
    label: "InventoryService",
    id: "inventory"
} 
service /inventory on new http:Listener(9090) {
    isolated resource function get flights/[string flightNumber](string? flightDate) returns Flight[] {
        if flightDate is () {
            return findByFlightNumber(flightNumber);
        } else {
            Flight? found = find(flightNumber, flightDate);
            if found is () {
                return [];
            } else {
                return [found];
            }
        }
    }

    isolated resource function post flights(@http:Payload SeatAllocation payload) returns SeatAllocation |error {
        return adjustInventory(payload);
    }
}

isolated function find(string flightNumber, string flightDate) returns Flight? {
    log:printInfo("Flight Date : " + flightDate);
    lock {
        return flightInventory.cloneReadOnly()[flightNumber, flightDate];
    }
    
}

isolated function findByFlightNumber(string flightNumber) returns Flight[] {
    lock {
        Flight[] flights = from var f in flightInventory
            where f.flightNumber == flightNumber
            order by f.flightDate
            select f;
        return flights.cloneReadOnly();
    }
}

isolated function adjustInventory(SeatAllocation seatAllocation) returns SeatAllocation|error {
    Flight? inventory = find(seatAllocation.flightNumber, seatAllocation.flightDate);
    if inventory is () {
        return error(string `inventory not found for flight number: ${seatAllocation.flightNumber}, flight date : ${seatAllocation.flightDate}`);
    }

    if seatAllocation.seats > inventory.available {
        return error(string `not enought seats for flight number: ${seatAllocation.flightNumber}, flight date : ${seatAllocation.flightDate}`);
    }

    inventory.available = inventory.available - seatAllocation.seats;
    return seatAllocation;
}

isolated table<Flight> key(flightNumber, flightDate) flightInventory = table [
    {
        flightNumber: "FL1",
        flightDate: "2022/03/15",
        available: 100,
        totalCapacity: 100
    },
    {
        flightNumber: "FL2",
        flightDate: "2022/03/15",
        available: 100,
        totalCapacity: 100
    },
    {
        flightNumber: "FL3",
        flightDate: "2022/03/16",
        available: 100,
        totalCapacity: 100
    },
    {
        flightNumber: "FL4",
        flightDate: "2022/03/16",
        available: 100,
        totalCapacity: 100
    },
    {
        flightNumber: "FL1",
        flightDate: "2022/03/21",
        available: 100,
        totalCapacity: 100
    }
];