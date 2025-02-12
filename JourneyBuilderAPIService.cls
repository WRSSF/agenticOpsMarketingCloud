public with sharing class JourneyBuilderAPIService {
    //these values coincide with fixed assets in a given Salesforce Marketing Cloud instance
    private static final String SENDER_PROFILE_ID = 'alpha';
    private static final String DELIVERY_PROFILE_ID = 'beta';
    private static final String SEND_CLASSIFICATION_ID = 'gamma';
    private static final String DATA_EXTENSION_ID = 'delta';
    private static final String EVENT_DEFINITION_KEY = 'epsilon';
    private static final String EVENT_DEFINITION_ID = 'zeta';


   //this is an enum specfic to wait step time interval scale in the Journey Builder paradigm
    private static final Set<String> VALID_WAIT_UNITS = new Set<String>{
        'MINUTES', 'HOURS', 'DAYS', 'WEEKS', 'MONTHS'
    };
    
    private static final String DEFAULT_WAIT_UNIT = 'DAYS';

    //invocable method established to wield in front end
    @InvocableMethod(label='Create Marketing Cloud Journey')
    public static List<Response> createJourney(List<Request> requests) {
        Request input = requests[0];
        //these are inputs collected from auto-launched flows via an Agent, or via Screen flows for other contexts
        String journeyName = input.journeyName;
        String firstEmailId = input.firstEmailId;
        String secondEmailId = input.secondEmailId;
        Integer waitDuration = input.waitDuration;
        String emailCopy = input.emailCopy;
        String waitUnit = (input.waitUnit?.toUpperCase() != null && VALID_WAIT_UNITS.contains(input.waitUnit.toUpperCase()))
            ? input.waitUnit.toUpperCase()
            : DEFAULT_WAIT_UNIT;

        // this builds the Journey Definition in Marketing Cloud. Note that there are contacts referenced in abstract form
        // that will be replaced by the Journey Builder API with references to the Contact's ID in Marketing Cloud
        Map<String, Object> journeyDefinition = new Map<String, Object>{
            'key' => journeyName.replaceAll('\\s+', '-').toLowerCase(),
            'name' => journeyName,
            'description' => 'Journey created via Apex',
            'workflowApiVersion' => 1.0,
            'entryMode' => 'MultipleEntries',
            'channel' => 'email',
            'defaults' => new Map<String, Object>{
                'email' => new List<String>{
                    '{{InteractionDefaults.Email}}',
                    '{{Contact.Default.Email}}'
                }
            },
            'triggers' => new List<Object>{
                new Map<String, Object>{
                    'key' => 'TRIGGER',
                    'name' => 'TRIGGER',
                    'type' => 'APIEvent',
                    'outcomes' => new List<Object>(),
                    'arguments' => new Map<String, Object>{
                        'contactKey' => '{{Event.ContactKey}}'
                    },
                    'configurationArguments' => new Map<String, Object>{
                        'applicationExtensionKey' => 'jb-api-event'
                    },
                    'metaData' => new Map<String, Object>{
                        'isConfigured' => true,
                        'configurationRequired' => false,
                        'eventDefinitionKey' => EVENT_DEFINITION_KEY,
                        'eventDefinitionId' => EVENT_DEFINITION_ID,
                        'entrySourceGroupConfigUrl' => 'jb:///data/entry/api-event/entrysourcegroupconfig.json'
                    }
                }
            }
        };

        List<Object> activities = new List<Object>();

        Map<String, Object> firstEmailActivity = new Map<String, Object>{
            'key' => 'SEND-EMAIL-1',
            'name' => input.firstEmailSubject,
            'type' => 'EMAILV2',
            'configurationArguments' => new Map<String, Object>{
                'triggeredSend' => new Map<String, Object>{
                    'autoAddSubscribers' => true,
                    'autoUpdateSubscribers' => true,
                    'emailId' => firstEmailId,
                    'emailSubject' => input.firstEmailSubject,
                    'preHeader' => input.firstEmailPreheader,
                    'senderProfileId' => SENDER_PROFILE_ID,
                    'deliveryProfileId' => DELIVERY_PROFILE_ID,
                    'sendClassificationId' => SEND_CLASSIFICATION_ID,
                    'isMultipart' => true,
                    'isTrackingClicks' => true,
                    'isSendLogging' => true,
                    'isSalesforceTracking' => true
                },
                'applicationExtensionKey' => 'jb-email-activity'
            },
            'metaData' => new Map<String, Object>{
                'icon' => '/images/icon-email.svg',
                'iconSmall' => '/images/icon-email.svg',
                'category' => 'message',
                'isConfigured' => true
            },
            'outcomes' => new List<Object>{
                new Map<String, Object>{
                    'key' => 'SEND-EMAIL-1-OUTCOME',
                    'next' => 'WAIT-1',
                    'metaData' => new Map<String, Object>{
                        'invalid' => false
                    }
                }
            }
        };

        activities.add(firstEmailActivity);

        Map<String, Object> waitActivity = new Map<String, Object>{
            'key' => 'WAIT-1',
            'name' => 'Wait Duration',
            'type' => 'WAIT',
            'configurationArguments' => new Map<String, Object>{
                'waitDuration' => waitDuration,
                'waitUnit' => waitUnit,
                'timeZoneId' => 'Central Standard Time'
            },
            'metaData' => new Map<String, Object>{
                'isConfigured' => true
            },
            'outcomes' => new List<Object>{
                new Map<String, Object>{
                    'key' => 'WAIT-1-OUTCOME',
                    'next' => 'SEND-EMAIL-2',
                    'metaData' => new Map<String, Object>{
                        'invalid' => false
                    }
                }
            }
        };

        activities.add(waitActivity);

        Map<String, Object> secondEmailActivity = new Map<String, Object>{
            'key' => 'SEND-EMAIL-2',
            'name' => 'Email 2: ' + input.secondEmailSubject,
            'type' => 'EMAILV2',
            'configurationArguments' => new Map<String, Object>{
                'triggeredSend' => new Map<String, Object>{
                    'autoAddSubscribers' => true,
                    'autoUpdateSubscribers' => true,
                    'emailId' => secondEmailId,
                    'emailSubject' => input.secondEmailSubject,
                    'preHeader' => input.secondEmailPreheader,
                    'senderProfileId' => SENDER_PROFILE_ID,
                    'deliveryProfileId' => DELIVERY_PROFILE_ID,
                    'sendClassificationId' => SEND_CLASSIFICATION_ID,
                    'isMultipart' => true,
                    'isTrackingClicks' => true,
                    'isSendLogging' => true,
                    'isSalesforceTracking' => true
                },
                'applicationExtensionKey' => 'jb-email-activity'
            },
            'metaData' => new Map<String, Object>{
                'icon' => '/images/icon-email.svg',
                'iconSmall' => '/images/icon-email.svg',
                'category' => 'message',
                'isConfigured' => true
            }
        };

        activities.add(secondEmailActivity);

        //note that each of the artifacts referenced above are placed as activities into the following object
        journeyDefinition.put('activities', activities);

        Http h = new Http();
        HttpRequest req = new HttpRequest();
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        //here we serialize the Journey Definition to JSON for REST transmission
        req.setBody(JSON.serialize(journeyDefinition));
        req.setEndpoint('callout:MCE_REST/interaction/v1/interactions');
       
        List<Response> responses = new List<Response>();
        Response response = new Response();
       
        //here we make the outbound API call to Marketing Cloud with error correction
        try {
            HttpResponse res = h.send(req);
            response.responseBody = res.getBody();
            response.statusCode = res.getStatusCode();
            response.success = res.getStatusCode() == 201;
           
            if (!response.success) {
                response.errorMessage = 'Failed to create journey. Status: ' + res.getStatusCode() + '. Message: ' + res.getBody();
            }
        } catch(Exception e) {
            response.errorMessage = 'Exception occurred: ' + e.getMessage();
            response.statusCode = 500;
            response.success = false;
        }
       
        responses.add(response);
        //the list of responses must be returned from the method for the Agent or Flow to receive it
        return responses;
    }

    //these are the input parameters expected by the flow action.
    //specifically, the Request object is what one would like to relay into the action, and the Response is
    //what is returned from the action.

    public class Request {
        @InvocableVariable(required=true)
        public String journeyName;

        @InvocableVariable(required=true)
        public String emailCopy;
       
        @InvocableVariable(required=true)
        public String firstEmailId;
       
        @InvocableVariable(required=true)
        public String firstEmailSubject;
       
        @InvocableVariable(required=true)
        public String firstEmailPreheader;
       
        @InvocableVariable(required=true)
        public String secondEmailId;
       
        @InvocableVariable(required=true)
        public String secondEmailSubject;
       
        @InvocableVariable(required=true)
        public String secondEmailPreheader;
       
        @InvocableVariable(required=true)
        public Integer waitDuration;
       
        @InvocableVariable(required=true)
        public String waitUnit;
    }
   
    public class Response {
        @InvocableVariable(required=true)
        public String responseBody;
       
        @InvocableVariable(required=true)
        public Integer statusCode;
       
        @InvocableVariable(required=true)
        public Boolean success;
       
        @InvocableVariable(required=true)
        public String errorMessage;
    }
}
