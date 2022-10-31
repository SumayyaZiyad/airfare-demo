import ballerina/http;

public type Fare record {
    string flightNo;
    string flightDate;
    float fare;
};

@display {
    label: "FaresService",
    id: "fares"
}
service /fares on new http:Listener(8080) {
    # A resource for generating greetings
    # + name - the input string name
    # + return - string name with hello message or error
    resource function get fare/[string flightNumber]/[string flightDate](string name) returns Fare|error {
        Fare fare = {flightNo: flightNumber, flightDate: flightDate, fare: 127.54};
        return fare;
    }
}
