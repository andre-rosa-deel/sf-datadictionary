@isTest
global class DataDictionaryCalloutMock implements HttpCalloutMock {
    protected Integer statusCode;
    protected String status;
    protected String body;

    // This is the required constructor that the test class will call.
    public DataDictionaryCalloutMock(
        Integer statusCode,
        String status,
        String body
    ) {
        this.statusCode = statusCode;
        this.status = status;
        this.body = body;
    }

    // This method is required by the HttpCalloutMock interface.
    // It returns the fake response.
    global HttpResponse respond(HttpRequest req) {
        HttpResponse res = new HttpResponse();
        res.setHeader('Content-Type', 'application/json');
        res.setBody(this.body);
        res.setStatusCode(this.statusCode);
        res.setStatus(this.status);
        return res;
    }
}
