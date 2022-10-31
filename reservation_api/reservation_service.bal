import ballerinax/twilio;
import aneesha/booking_api;
import aneesha/inventory_api;
import ballerina/log;
import ballerina/http;

public type Reservation record {
    *inventory_api:SeatAllocation;
    string origin;
    string destination;
    string contactNo;
};

configurable string twilioAccountSId = ?;
configurable string twilioAuthToken = ?;

configurable string bookingAPIUrl = "http://localhost:7070";

@display {
    label: "ReservationService",
    id: "reservation"
}
service /flights on new http:Listener(6060) {
    resource function post reservation(@http:Payload Reservation reservation) returns Reservation|error? {
        log:printInfo("Received reservation request for " + reservation.flightNumber);

        @display {
            label: "BookingsService",
            id: "bookings"
        }
        http:Client bookings_apiEndpoint = check new (bookingAPIUrl);
        http:Request bookingRequest = new;
        bookingRequest.setPayload({flightNumber: reservation.flightNumber, origin: reservation.origin, destination: reservation.destination, flightDate: reservation.flightDate, seats: reservation.seats});
        booking_api:BookingRecord bookingResponse = check bookings_apiEndpoint->/booking.post(bookingRequest);
        log:printInfo("Saved Booking : " + bookingResponse.toBalString());
        
        twilio:Client twilioEndpoint = check new ({auth: {accountSId: twilioAccountSId, authToken: twilioAuthToken}}, {});
        twilio:SmsResponse smsResponse = check twilioEndpoint->sendSms("+18312449432", reservation.contactNo, "Booking confirmed for flight " + reservation.flightNumber);
        log:printInfo("SMS Sent " + smsResponse.toBalString());
        return reservation;
    }

    resource function get book() {}
}