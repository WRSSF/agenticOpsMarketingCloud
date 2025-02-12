public with sharing class CreateMarketingCloudEmail {
     //invocable method established to wield in front end
    @InvocableMethod(label = 'Create Marketing Cloud Email')
    public static List<Response> createMCEmail(List<Request> requests) {
        Request input = requests[0];
        //an stringified current timestamp is appended to the email name gathered in Agent interaction to ensure uniqueness
        String timestamp = Datetime.now().format('yyyyMMdd_HHmmss');
        String uniqueEmailName = input.emailName + '_' + timestamp;
        
        //these are inputs collected from auto-launched flows via an Agent, or via Screen flows for other contexts
        String emailSubject = input.emailSubject;
        String emailPreheader = input.emailPreheader;
        String emailCopy = input.emailCopy;

        //here, a template is retrieved from the org, and the data is pulled from the context, and string replacement is performed
        //Agentforce can also create content quite readily via prompt alone in this paradigm
        List<mceEmailData__c> kontentObjekt = [
            SELECT mceEmailPayload__c FROM mceEmailData__c WHERE Name = 'Alpha' LIMIT 1
        ];
        
        if (kontentObjekt.isEmpty()) {
            return createErrorResponse('Email template "Alpha" not found');
        }

        String emailContent = kontentObjekt[0].mceEmailPayload__c.replace('ExampleResponsiveEmailPlatzhalter', emailCopy);

        //all necessary elements for successful API creation of the email are instantiated here
        EmailPayload emailPayload = new EmailPayload();
        emailPayload.name = uniqueEmailName;

        emailPayload.channels = new Channels();
        emailPayload.channels.email = true;
        emailPayload.channels.web = false;

        emailPayload.views = new Views();
        emailPayload.views.html = new HtmlView();
        emailPayload.views.html.content = emailContent;
        emailPayload.views.text = new Map<String, String>();
        emailPayload.views.subjectline = new SubjectLineView();
        emailPayload.views.subjectline.content = emailSubject;
        emailPayload.views.preheader = new PreheaderView();
        emailPayload.views.preheader.content = emailPreheader;

        emailPayload.assetType = new AssetType();
        emailPayload.assetType.name = 'htmlemail';
        emailPayload.assetType.id = 208;

        HttpResponse res = makeAPICall(emailPayload);
        
        //here is error correction against the inbound call if uniqueness must be enforced
        if (res.getStatusCode() == 400) {
            String suggestedName = extractSuggestedName(res.getBody());
            if (String.isNotBlank(suggestedName)) {
                emailPayload.name = suggestedName + '_' + timestamp;
                res = makeAPICall(emailPayload);
            }
        }

        List<Response> responses = new List<Response>();
        Response answer = new Response();

        //here a successful API response is parsed so that it can be forwarded to the interacting Agent
        if (res.getStatusCode() == 201) {
            Map<String, Object> responseMap = (Map<String, Object>)JSON.deserializeUntyped(res.getBody());
            answer.success = true;
            answer.statusMessage = 'Email created successfully with name: ' + emailPayload.name;
            answer.legacyId = extractLegacyId(responseMap);
            answer.emailSubject = emailSubject;
            answer.emailPreheader = emailPreheader;
            answer.finalEmailName = emailPayload.name;
        } else {
            answer.success = false;
            answer.statusMessage = 'Failed to create email. Status Code: ' + res.getStatusCode() + '. Response: ' + res.getBody();
        }

        responses.add(answer);
        return responses;
    }

    //isolated function to create content assets in Content Builder via API
    private static HttpResponse makeAPICall(EmailPayload emailPayload) {
        Http h = new Http();
        HttpRequest req = new HttpRequest();
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setBody(JSON.serialize(emailPayload));
        req.setEndpoint('callout:MCE_REST/asset/v1/content/assets');
        
        try {
            return h.send(req);
        } catch (Exception e) {
            HttpResponse errorResponse = new HttpResponse();
            errorResponse.setStatusCode(500);
            errorResponse.setBody('Internal error: ' + e.getMessage());
            return errorResponse;
        }
    }

    //this string houses the suggested string from the API
    private static String extractSuggestedName(String responseBody) {
        try {
            Map<String, Object> errorResponse = (Map<String, Object>)JSON.deserializeUntyped(responseBody);
            List<Object> validationErrors = (List<Object>)errorResponse.get('validationErrors');
            
            if (validationErrors != null && !validationErrors.isEmpty()) {
                Map<String, Object> firstError = (Map<String, Object>)validationErrors[0];
                String errorMessage = (String)firstError.get('message');
                
                if (String.isNotBlank(errorMessage) && errorMessage.contains('Suggested name:')) {
                    String suggestedName = errorMessage.substringAfter('Suggested name:').trim();
                    suggestedName = suggestedName.removeEnd(')').removeEnd('(').trim();
                    return suggestedName;
                }
            }
        } catch (Exception e) {
            System.debug('Error parsing suggested name: ' + e.getMessage());
        }
        return null;
    }

    private static List<Response> createErrorResponse(String errorMessage) {
        Response answer = new Response();
        answer.success = false;
        answer.statusMessage = errorMessage;
        return new List<Response>{answer};
    }

    //this function parses the API response and extracts the legacyId of the email 
    private static String extractLegacyId(Map<String, Object> responseMap) {
        if (responseMap.containsKey('data')) {
            Map<String, Object> data = (Map<String, Object>)responseMap.get('data');
            if (data.containsKey('email')) {
                Map<String, Object> email = (Map<String, Object>)data.get('email');
                if (email.containsKey('legacy')) {
                    Map<String, Object> legacy = (Map<String, Object>)email.get('legacy');
                    if (legacy.containsKey('legacyId')) {
                        return String.valueOf(legacy.get('legacyId'));
                    }
                }
            }
        }

        if (responseMap.containsKey('legacyData')) {
            Map<String, Object> legacyData = (Map<String, Object>)responseMap.get('legacyData');
            if (legacyData.containsKey('legacyId')) {
                return String.valueOf(legacyData.get('legacyId'));
            }
        }
        return null;
    }

    //the objects needed for email creation are built here for the sake of efficiency
    public class EmailPayload {
        public String name;
        public Channels channels;
        public Views views;
        public AssetType assetType;
    }

    public class Channels {
        public Boolean email;
        public Boolean web;
    }

    public class Views {
        public HtmlView html;
        public Map<String, String> text;
        public SubjectLineView subjectline;
        public PreheaderView preheader;
    }

    public class HtmlView {
        public String content;
    }

    public class SubjectLineView {
        public String content;
    }

    public class PreheaderView {
        public String content;
    }

    public class AssetType {
        public String name;
        public Integer id;
    }

    //these are the input parameters expected by the flow action.
    //specifically, the Request object is what one would like to relay into the action, and the Response is
    //what is returned from the action.
    public class Request {
        @InvocableVariable(required=true)
        public String emailName;

        @InvocableVariable(required=true)
        public String emailSubject;

        @InvocableVariable(required=true)
        public String emailCopy;

        @InvocableVariable
        public String emailPreheader;
    }

    public class Response {
        @InvocableVariable
        public Boolean success;

        @InvocableVariable
        public String statusMessage;

        @InvocableVariable
        public String legacyId;

        @InvocableVariable
        public String emailSubject;

        @InvocableVariable
        public String emailPreheader;

        @InvocableVariable
        public String finalEmailName;
    }
}
