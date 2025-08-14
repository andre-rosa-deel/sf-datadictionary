public class DataDictionaryHttpClass {
    public static final String PICKLIST_ENDPOINT = '{0}/services/data/{1}/ui-api/object-info/{2}/picklist-values/{3}';
    public static final String TOOLING_QUERY_ENDPOINT = '{0}/services/data/{1}/tooling/query/?q={2}';
    public static final String METHOD_GET = 'GET';
    public static final String API_VERSION = 'v63.0';

    public static Map<String, Object> getPicklists(
        String recordTypesObject,
        Id recordTypeId,
        String token
    ) {
        return invoke(
            String.format(
                PICKLIST_ENDPOINT,
                new List<String>{
                    Url.getOrgDomainUrl().toExternalForm(),
                    API_VERSION,
                    recordTypesObject,
                    recordTypeId
                }
            ),
            METHOD_GET,
            token
        );
    }

    public static Map<String, Object> getMetadataReferences(
        String query,
        String token
    ) {
        return invoke(
            String.format(
                TOOLING_QUERY_ENDPOINT,
                new List<String>{
                    Url.getOrgDomainUrl().toExternalForm(),
                    API_VERSION,
                    EncodingUtil.urlEncode(query, 'UTF-8')
                }
            ),
            METHOD_GET,
            token
        );
    }

    @TestVisible
    private static Map<String, Object> invoke(
        String endpoint,
        String method,
        String token
    ) {
        List<DataDictionaryObjects.HeaderObject> headerList = new List<DataDictionaryObjects.HeaderObject>();

        DataDictionaryObjects.HeaderObject headerObjectAuth = new DataDictionaryObjects.HeaderObject();
        headerObjectAuth.key = 'Authorization';
        headerObjectAuth.value = 'Bearer ' + token;
        headerList.add(headerObjectAuth);

        DataDictionaryObjects.HeaderObject headerObjContent = new DataDictionaryObjects.HeaderObject();
        headerObjContent.key = 'Content-Type';
        headerObjContent.value = 'application/json';
        headerList.add(headerObjContent);
        HttpResponse response = doRequest(endpoint, method, headerList);

        if (response.getStatusCode() == 200) {
            return (Map<String, Object>) JSON.deserializeUntyped(
                response.getBody()
            );
        } else {
            return null;
        }
    }

    @TestVisible
    private static HttpResponse doRequest(
        String endPoint,
        String method,
        List<DataDictionaryObjects.HeaderObject> headerObj
    ) {
        List<DataDictionaryObjects.HeaderObject> headerList = new List<DataDictionaryObjects.HeaderObject>();
        headerList = headerObj;

        Http http = new Http();
        HttpRequest request = new HttpRequest();
        request.setEndpoint(endPoint);
        request.setMethod(method.toUpperCase());
        for (DataDictionaryObjects.HeaderObject headerItem : headerObj) {
            request.setHeader(headerItem.key, headerItem.value);
        }

        HttpResponse response = http.send(request);
        return response;
    }
}
