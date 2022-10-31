import aneesha/inventory_api;
import aneesha/fares_api;
import ballerina/log;
import ballerina/http;
import ballerina/time;

type ApiCredentials record {|
    string clientId;
    string clientSecret;
|};

public enum BookingStatus {
    NEW,
    BOOKING_CONFIRMED,
    CHECKED_IN
}

public type BookingRecord record {
    *fares_api:Fare;
    readonly int id;
    string origin;
    string destination;
    string bookingDate;
    int seats;
    BookingStatus status;
};

public type Booking record {
    string flightNumber;
    string origin;
    string destination;
    string flightDate;
    int seats;
};

type PassengerFare record {
    Passenger passenger?;
    fares_api:Fare[] fare;
    BookingRecord? bookingRec;
};

type Passenger record {
    string firstName;
    string lastName;
    string passportNumber;
};

configurable string inventoryAPIUrl = "http://localhost:9090";
configurable string fareAPIUrl = "http://localhost:8080";

listener http:Listener bListener = new http:Listener(7070);

@display {
    label: "BookingsService",
    id: "bookings"
}
isolated service /bookings on bListener {
    private table<BookingRecord> key(id) bookingInventory = table [];

    resource function post booking(@http:Payload Booking payload) returns BookingRecord|error? {
        log:printInfo("making a new booking: " + payload.toJsonString());

        @display {
            label: "InventoryService",
            id: "inventory"
        }
        http:Client inventory_apiEndpoint = check new ("http://localhost:9090");
        http:Request flightReq = new;
        flightReq.setPayload({flightNumber: payload.flightNumber, flightDate: payload.flightDate, seats: payload.seats});
        
        inventory_api:SeatAllocation postInventoryAllocateResponse = check inventory_apiEndpoint->/flights.post(flightReq);

        @display {
            label: "FaresService",
            id: "fares"
        }
        http:Client fares_apiEndpoint = check new (fareAPIUrl);
        fares_api:Fare fare = check fares_apiEndpoint->/fare/[payload.flightNumber]/[payload.flightDate].get;
        
        lock {
            BookingRecord newBooking = {
                id: self.bookingInventory.nextKey(),
                fare: fare.fare,
                flightDate: postInventoryAllocateResponse.flightDate,
                origin: payload.origin,
                destination: payload.destination,
                bookingDate: currentDate(),
                flightNo: postInventoryAllocateResponse.flightNumber,
                seats: payload.seats,
                status: BOOKING_CONFIRMED
            };

            BookingRecord saved = self.saveBookingRecord(newBooking);
            return saved.cloneReadOnly();
        }

    }

    isolated resource function get booking/[int id]() returns BookingRecord|error? {
        lock {
            return self.bookingInventory[id].cloneReadOnly();
        }
        
    }

    isolated resource function delete booking/[int id]() returns BookingRecord|error? {
        lock {
            return self.bookingInventory.remove(id).cloneReadOnly();
        }
    }

    isolated resource function put booking/[int id] (@http:Payload BookingRecord bookingInfo) returns http:Response {
        http:Response response = new;
        lock {
            self.bookingInventory.put(bookingInfo.cloneReadOnly());
            response.statusCode = http:STATUS_OK;
        }
        return response;
        
    }

    isolated resource function post changestatus/[int id]/status/[string bookingStatus]() returns error? {
        BookingRecord? bookingRecord;
        lock {
            bookingRecord = (self.bookingInventory.cloneReadOnly())[id];
        }
        if bookingRecord is () {
            return error(string `unable to find the booking record, id: ${id}, booking status: ${bookingStatus}`);
        }
        bookingRecord.status = <BookingStatus>bookingStatus;
    }

    isolated function saveBookingRecord(BookingRecord bookingRecord) returns BookingRecord {
        BookingRecord saved;
        lock {
            saved = {
                        id: self.bookingInventory.nextKey(),
                        fare: bookingRecord.fare,
                        flightDate: bookingRecord.flightDate,
                        origin: bookingRecord.origin,
                        destination: bookingRecord.destination,
                        bookingDate: bookingRecord.bookingDate,
                        flightNo: bookingRecord.flightNo,
                        seats: bookingRecord.seats,
                        status: BOOKING_CONFIRMED
                    };
            self.bookingInventory.add(saved.cloneReadOnly());
        }
        return saved;
    }
}

isolated function currentDate() returns string {
    time:Civil civil = time:utcToCivil(time:utcNow());
    return string `${civil.year}/${civil.month}/${civil.day}`;
}