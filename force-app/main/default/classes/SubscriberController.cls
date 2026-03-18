public with sharing class SubscriberController {

    // ── Inner class — elevated reads only, no DML ─────────────────────
    private without sharing class ElevatedReader {
        public List<Blog_Subscriber__c> findByEmail(String email) {
            return [
                SELECT Id, Is_Active__c, Token__c, Name
                FROM Blog_Subscriber__c
                WHERE Email__c = :email
                LIMIT 1
            ];
        }
    }

    // ── Elevated writer — bypasses sharing for DML only ───────────────
    private without sharing class ElevatedWriter {
        public void insertRecord(Blog_Subscriber__c rec) {
            insert rec;
        }
        public void updateRecord(Blog_Subscriber__c rec) {
            update rec;
        }
    }
    
    // ── CHECK STATUS ──────────────────────────────────────────────────────
    // Returns: 'NEW' | 'ACTIVE' | 'INACTIVE'
    @AuraEnabled(cacheable=false)
    public static String checkSubscriptionStatus(String email) {
        if (String.isBlank(email)) return 'NEW';

        // List<Blog_Subscriber__c> existing = [
        //     SELECT Id, Is_Active__c, Token__c
        //     FROM Blog_Subscriber__c
        //     WHERE Email__c = :email.trim().toLowerCase()
        //     LIMIT 1
        // ];
        List<Blog_Subscriber__c> existing = new ElevatedReader().findByEmail(email.trim().toLowerCase());

        if (existing.isEmpty()) return 'NEW';
        return existing[0].Is_Active__c ? 'ACTIVE' : 'INACTIVE';
    }

    // ── SUBSCRIBE ─────────────────────────────────────────────────────────
    // Returns token string on success, throws on failure
    @AuraEnabled(cacheable=false)
    public static String subscribe(String name, String email) {
        if (String.isBlank(name) || String.isBlank(email)) {
            throw new AuraHandledException('Name and email are required.');
        }

        String cleanEmail = email.trim().toLowerCase();

        if (!isValidEmail(cleanEmail)) {
            throw new AuraHandledException('Please enter a valid email address.');
        }

        // Check for existing record
        // List<Blog_Subscriber__c> existing = [
        //     SELECT Id, Is_Active__c, Token__c, Name
        //     FROM Blog_Subscriber__c
        //     WHERE Email__c = :cleanEmail
        //     LIMIT 1
        // ];

        List<Blog_Subscriber__c> existing = new ElevatedReader().findByEmail(cleanEmail);

        String token;

        if (!existing.isEmpty()) {
            Blog_Subscriber__c sub = existing[0];

            if (sub.Is_Active__c) {
                // Already subscribed — return existing token so localStorage can be set
                return sub.Token__c;
            } else {
                // Previously unsubscribed — reactivate
                sub.Is_Active__c = true;
                sub.Name = name.trim();
                sub.Subscription_Date__c = Date.today();
                sub.Unsubscribe_Date__c = null;
                // update sub;
                new ElevatedWriter().updateRecord(sub);
                return sub.Token__c;
            }
        }

        // Brand new subscriber
        token = generateToken(cleanEmail);

        Blog_Subscriber__c newSub = new Blog_Subscriber__c(
            Name              = name.trim(),
            Email__c          = cleanEmail,
            Is_Active__c      = true,
            Subscription_Date__c = Date.today(),
            Token__c          = token
        );
        // insert newSub;
        new ElevatedWriter().insertRecord(newSub);

        return token;
    }

    // ── UNSUBSCRIBE ───────────────────────────────────────────────────────
    @AuraEnabled(cacheable=false)
    public static Boolean unsubscribe(String email, String token) {
        if (String.isBlank(email) || String.isBlank(token)) {
            throw new AuraHandledException('Invalid unsubscribe request.');
        }

        // List<Blog_Subscriber__c> existing = [
        //     SELECT Id, Is_Active__c, Token__c
        //     FROM Blog_Subscriber__c
        //     WHERE Email__c = :email.trim().toLowerCase()
        //     AND Token__c   = :token
        //     LIMIT 1
        // ];
        List<Blog_Subscriber__c> existing = new ElevatedReader().findByEmail(email.trim().toLowerCase());

        if (existing.isEmpty()) {
            throw new AuraHandledException('Subscription not found.');
        }

        existing[0].Is_Active__c        = false;
        existing[0].Unsubscribe_Date__c = Date.today();
        // update existing[0];
        new ElevatedWriter().updateRecord(existing[0]);

        return true;
    }

    // ── HELPERS ───────────────────────────────────────────────────────────
    private static String generateToken(String email) {
        String raw = email + String.valueOf(DateTime.now().getTime()) + String.valueOf(Math.random());
        Blob hash = Crypto.generateDigest('SHA-256', Blob.valueOf(raw));
        return EncodingUtil.convertToHex(hash).substring(0, 32);
    }

    private static Boolean isValidEmail(String email) {
        String emailRegex = '^[a-zA-Z0-9._|\\\\%#~`=?&/$^*!}{+-]+@[a-zA-Z0-9-]+\\.([a-zA-Z0-9-]{2,4}\\.){0,1}[a-zA-Z]{2,4}$';
        Pattern p = Pattern.compile(emailRegex);
        return p.matcher(email).matches();
    }

    @InvocableMethod(label='Send Subscriber Email via Brevo')
    public static void subscriptionNotifications(List<EmailRequest> requests) {
        for (EmailRequest req : requests) {
            sendEmailAsync(
                req.toEmail,
                req.toName,
                req.subject,
                req.body,
                req.fromEmail
            );
        }
    }

    @future(callout=true)
    private static void sendEmailAsync(String toEmail, String toName, String subject, String body, String fromEmail) {
        String cleanBody = body
            .replaceAll('<[^>]+>', '')
            .replaceAll('&nbsp;', ' ')
            .replaceAll('&amp;', '&')
            .replaceAll('\n{3,}', '\n\n')
            .trim();

        Map<String, Object> payload = new Map<String, Object>{
            'sender' => new Map<String, String>{
                'name'  => 'Govind Singh Solanki',
                'email' => fromEmail
            },
            'to' => new List<Map<String, String>>{
                new Map<String, String>{
                    'email' => toEmail,
                    'name'  => toName != null ? toName : ''
                }
            },
            'subject' => subject,
            'textContent' => cleanBody
        };

        Http http = new Http();
        HttpRequest hReq = new HttpRequest();

        // ✅ Named Credential handles URL + api-key header automatically
        hReq.setEndpoint('callout:Brevo/smtp/email');
        hReq.setMethod('POST');
        hReq.setHeader('content-type', 'application/json');
        hReq.setBody(JSON.serialize(payload));
        hReq.setTimeout(10000);

        HttpResponse hRes = http.send(hReq);

        if (hRes.getStatusCode() == 201) {
            System.debug('Brevo: email sent to ' + toEmail);
        } else {
            System.debug('Brevo error: ' + hRes.getStatusCode() + ' — ' + hRes.getBody());
        }
    }

    public class EmailRequest {
        @InvocableVariable(required=true)  public String toEmail;
        @InvocableVariable(required=true) public String toName;
        @InvocableVariable(required=true)  public String subject;
        @InvocableVariable(required=true)  public String body;
        @InvocableVariable(required=true) public String fromEmail;
    }

}