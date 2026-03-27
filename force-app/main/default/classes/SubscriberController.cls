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

    // @InvocableMethod(label='Send Subscriber Email via Brevo')
    // public static void subscriptionNotifications(List<EmailRequest> requests) {
    //     for (EmailRequest req : requests) {
    //         sendEmailAsync(
    //             req.toEmail,
    //             req.toName,
    //             req.subject,
    //             req.body,
    //             req.fromEmail
    //         );
    //     }
    // }

    @InvocableMethod(label='Send Subscriber Email via Brevo' description='Sends HTML subscription email. emailType: welcome | unsubscribe | resubscribe')
    public static void sendSubscriberEmail(List<EmailRequest> requests) {
        if (requests == null || requests.isEmpty()) return;
        EmailRequest req = requests[0];
        sendEmailAsync(
            req.toEmail,
            req.toName,
            req.emailType,
            req.fromEmail,
            req.siteBaseUrl
        );
    }

    // @future(callout=true)
    // private static void sendEmailAsync(String toEmail, String toName, String subject, String body, String fromEmail) {
    //     String cleanBody = body
    //         .replaceAll('<[^>]+>', '')
    //         .replaceAll('&nbsp;', ' ')
    //         .replaceAll('&amp;', '&')
    //         .replaceAll('\n{3,}', '\n\n')
    //         .trim();

    //     Map<String, Object> payload = new Map<String, Object>{
    //         'sender' => new Map<String, String>{
    //             'name'  => 'Govind Singh Solanki',
    //             'email' => fromEmail
    //         },
    //         'to' => new List<Map<String, String>>{
    //             new Map<String, String>{
    //                 'email' => toEmail,
    //                 'name'  => toName != null ? toName : ''
    //             }
    //         },
    //         'subject' => subject,
    //         'textContent' => cleanBody
    //     };

    //     Http http = new Http();
    //     HttpRequest hReq = new HttpRequest();

    //     // ✅ Named Credential handles URL + api-key header automatically
    //     hReq.setEndpoint('callout:Brevo/smtp/email');
    //     hReq.setMethod('POST');
    //     hReq.setHeader('content-type', 'application/json');
    //     hReq.setBody(JSON.serialize(payload));
    //     hReq.setTimeout(10000);

    //     HttpResponse hRes = http.send(hReq);

    //     if (hRes.getStatusCode() == 201) {
    //         System.debug('Brevo: email sent to ' + toEmail);
    //     } else {
    //         System.debug('Brevo error: ' + hRes.getStatusCode() + ' — ' + hRes.getBody());
    //     }
    // }

    @future(callout=true)
    private static void sendEmailAsync(
        String toEmail,
        String toName,
        String emailType,
        String fromEmail,
        String siteBaseUrl
    ) {
        String subject;
        String htmlContent;

        if (emailType == 'welcome') {
            subject     = 'You\'re subscribed to Govind\'s Salesforce Blog! 🎉';
            htmlContent = buildWelcomeHtml(siteBaseUrl);
        } else if (emailType == 'unsubscribe') {
            subject     = 'You\'ve unsubscribed from Govind\'s Salesforce Blog';
            htmlContent = buildUnsubscribeHtml(siteBaseUrl);
        } else if (emailType == 'resubscribe') {
            subject     = 'Welcome back to Govind\'s Salesforce Blog! 👋';
            htmlContent = buildResubscribeHtml(siteBaseUrl);
        } else {
            System.debug('sendEmailAsync: Unknown emailType = ' + emailType);
            return;
        }

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
            'subject'     => subject,
            'htmlContent' => htmlContent
        };

        Http http        = new Http();
        HttpRequest hReq = new HttpRequest();
        hReq.setEndpoint('callout:Brevo/smtp/email');
        hReq.setMethod('POST');
        hReq.setHeader('Content-Type', 'application/json');
        hReq.setBody(JSON.serialize(payload));
        hReq.setTimeout(10000);

        HttpResponse hRes = http.send(hReq);

        if (hRes.getStatusCode() == 201) {
            System.debug('Brevo: ' + emailType + ' email sent to ' + toEmail);
        } else {
            System.debug('Brevo error: ' + hRes.getStatusCode() + ' — ' + hRes.getBody());
        }
    }

    private static String wrapEmail(String innerRows) {
        return '<!DOCTYPE html><html lang="en">' +
        '<head><meta charset="UTF-8"/><meta name="viewport" content="width=device-width,initial-scale=1.0"/></head>' +
        '<body style="margin:0;padding:0;background:#f8fafc;font-family:\'Segoe UI\',Arial,sans-serif;">' +
        '<table width="100%" cellpadding="0" cellspacing="0" style="background:#f8fafc;padding:40px 16px;">' +
        '<tr><td align="center">' +
        '<table width="600" cellpadding="0" cellspacing="0" style="max-width:600px;width:100%;background:#ffffff;border-radius:16px;overflow:hidden;box-shadow:0 4px 24px rgba(0,0,0,0.08);">' +
        innerRows +
        '</table>' +
        '</td></tr></table>' +
        '</body></html>';
    }

    private static String buildHeader(String gradient, String emoji, String headline) {
        return '<tr><td style="background:' + gradient + ';padding:32px 40px;text-align:center;">' +
            '<p style="margin:0 0 6px 0;color:rgba(255,255,255,0.85);font-size:11px;font-weight:600;letter-spacing:0.1em;text-transform:uppercase;">Salesforce Developer Blog</p>' +
            '<h1 style="margin:0;color:#ffffff;font-size:22px;font-weight:800;letter-spacing:-0.02em;">' + emoji + '&nbsp;' + headline + '</h1>' +
        '</td></tr>';
    }

    private static String buildButton(String url, String label, String bg, String shadow) {
        return '<tr><td style="padding:24px 40px 8px;">' +
            '<a href="' + url + '" style="display:inline-block;background:' + bg + ';color:#ffffff;font-size:14px;font-weight:600;text-decoration:none;padding:13px 28px;border-radius:8px;box-shadow:0 4px 14px ' + shadow + ';">' +
                label + ' &rarr;' +
            '</a>' +
        '</td></tr>';
    }

    private static String buildFooter(String note) {
        return '<tr><td style="padding:24px 40px 0;"><hr style="border:none;border-top:1px solid #e2eaf4;margin:0;"/></td></tr>' +
        '<tr><td style="padding:20px 40px 28px;text-align:center;">' +
            '<p style="margin:0 0 4px 0;font-size:12px;color:#9aaabb;">' + note + '</p>' +
            '<p style="margin:0;font-size:12px;color:#b0bec5;">Govind Singh Solanki &middot; Salesforce Developer</p>' +
        '</td></tr>';
    }

    private static String buildWelcomeHtml(String siteBaseUrl) {
        String blogUrl = siteBaseUrl + '/blogs';
        String rows =
            buildHeader('linear-gradient(135deg,#0070d2,#1589ee)', '🎉', 'Welcome Aboard!') +
            '<tr><td style="padding:32px 40px 0;">' +
                '<p style="margin:0 0 14px 0;font-size:16px;font-weight:700;color:#1a1a2e;">You\'re now subscribed!</p>' +
                '<p style="margin:0 0 16px 0;font-size:15px;color:#5a6a7e;line-height:1.75;">Thanks for subscribing to my Salesforce Developer Blog. You\'ll be the first to know whenever I publish new posts on topics like:</p>' +
                '<table cellpadding="0" cellspacing="0">' +
                    '<tr><td style="padding:4px 0;font-size:14px;color:#5a6a7e;">&#9889; Lightning Web Components &amp; LWR</td></tr>' +
                    '<tr><td style="padding:4px 0;font-size:14px;color:#5a6a7e;">&#129302; Agentforce &amp; Einstein AI</td></tr>' +
                    '<tr><td style="padding:4px 0;font-size:14px;color:#5a6a7e;">&#128295; Apex, Flows &amp; Integrations</td></tr>' +
                    '<tr><td style="padding:4px 0;font-size:14px;color:#5a6a7e;">&#128640; Real-world Salesforce Solutions</td></tr>' +
                '</table>' +
            '</td></tr>' +
            buildButton(blogUrl, 'Browse the Blog', 'linear-gradient(135deg,#0070d2,#1589ee)', 'rgba(0,112,210,0.3)') +
            buildFooter('You\'re receiving this because you subscribed to Govind\'s Salesforce Blog.');
        return wrapEmail(rows);
    }

    private static String buildUnsubscribeHtml(String siteBaseUrl) {
        String blogUrl = siteBaseUrl + '/blogs';
        String rows =
            buildHeader('linear-gradient(135deg,#5a6a7e,#7a8a9e)', '👋', 'You\'ve Unsubscribed') +
            '<tr><td style="padding:32px 40px 0;">' +
                '<p style="margin:0 0 14px 0;font-size:16px;font-weight:700;color:#1a1a2e;">Sorry to see you go!</p>' +
                '<p style="margin:0 0 14px 0;font-size:15px;color:#5a6a7e;line-height:1.75;">You\'ve been successfully removed from my blog mailing list. You won\'t receive any further email notifications from me.</p>' +
                '<p style="margin:0 0 14px 0;font-size:15px;color:#5a6a7e;line-height:1.75;">Changed your mind? You can always resubscribe by visiting the blog — the Subscribe button will be waiting for you.</p>' +
            '</td></tr>' +
            buildButton(blogUrl, 'Visit the Blog', 'linear-gradient(135deg,#5a6a7e,#7a8a9e)', 'rgba(90,106,126,0.25)') +
            buildFooter('You\'re receiving this because you recently unsubscribed from Govind\'s Salesforce Blog.');
        return wrapEmail(rows);
    }

    private static String buildResubscribeHtml(String siteBaseUrl) {
        String blogUrl = siteBaseUrl + '/blogs';
        String rows =
            buildHeader('linear-gradient(135deg,#0070d2,#00a1e0)', '👋', 'Welcome Back!') +
            '<tr><td style="padding:32px 40px 0;">' +
                '<p style="margin:0 0 14px 0;font-size:16px;font-weight:700;color:#1a1a2e;">Great to have you back!</p>' +
                '<p style="margin:0 0 14px 0;font-size:15px;color:#5a6a7e;line-height:1.75;">You\'ve successfully resubscribed to my Salesforce Developer Blog. You\'ll receive notifications for all new posts going forward.</p>' +
                '<p style="margin:0 0 14px 0;font-size:15px;color:#5a6a7e;line-height:1.75;">While you were away, you might have missed some posts — check out the latest ones on the blog!</p>' +
            '</td></tr>' +
            buildButton(blogUrl, 'See Latest Posts', 'linear-gradient(135deg,#0070d2,#00a1e0)', 'rgba(0,112,210,0.3)') +
            buildFooter('You\'re receiving this because you resubscribed to Govind\'s Salesforce Blog.');
        return wrapEmail(rows);
    }

    // public class EmailRequest {
    //     @InvocableVariable(required=true)  public String toEmail;
    //     @InvocableVariable(required=true) public String toName;
    //     @InvocableVariable(required=true)  public String subject;
    //     @InvocableVariable(required=true)  public String body;
    //     @InvocableVariable(required=true) public String fromEmail;
    // }

    public class EmailRequest {
        @InvocableVariable(required=true  label='To Email')
        public String toEmail;

        @InvocableVariable(required=true  label='To Name')
        public String toName;

        @InvocableVariable(required=true  label='Email Type (welcome / unsubscribe / resubscribe)')
        public String emailType;

        @InvocableVariable(required=true  label='From Email (verified Brevo sender)')
        public String fromEmail;

        @InvocableVariable(required=true  label='Site Base URL (e.g. https://yoursite.com)')
        public String siteBaseUrl;
    }

}