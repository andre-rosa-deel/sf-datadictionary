@isTest
private class HttpClass_Test {

    @isTest
    static void testUiApiResponse_Success() {
        // This test validates the handling of a successful 200 response.

        // 1. Setup: Define a mock JSON response and set the mock callout.
        String successBody = '{"key":"testValue"}';
        Test.setMock(HttpCalloutMock.class, new DataDictionaryCalloutMock(200, 'OK', successBody));

        // 2. Action
        Test.startTest();
        Map<String, Object> result = HttpClass.uiAPIResponse('Account', '012000000000000AAA', 'TEST_TOKEN');
        Test.stopTest();

        // 3. Assert
        System.assertNotEquals(null, result, 'The result map should not be null on success.');
        System.assertEquals('testValue', result.get('key'), 'The map should contain the parsed JSON values.');
    }

    @isTest
    static void testUiApiResponse_Failure() {
        // This test validates the handling of a non-200 error response.

        // 1. Setup: Set the mock to simulate a server error.
        Test.setMock(HttpCalloutMock.class, new DataDictionaryCalloutMock(500, 'Server Error', ''));

        // 2. Action
        Test.startTest();
        Map<String, Object> result = HttpClass.uiAPIResponse('Account', '012000000000000AAA', 'TEST_TOKEN');
        Test.stopTest();

        // 3. Assert
        System.assertEquals(null, result, 'The result map should be null on a non-200 response.');
    }
}