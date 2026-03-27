public with sharing class SubscriberNotifications {
    
    @InvocableMethod(label='Blog Publish Notification')
    public static void sendBlogNotification(List<BlogNotificationRequest> requests) {
        if (requests == null || requests.isEmpty()) return;

        BlogNotificationRequest req = requests[0];

        // Fetch all active subscribers — elevated read to bypass guest sharing
        List<Blog_Subscriber__c> subscribers = new ElevatedReader().getActiveSubscribers();

        if (subscribers.isEmpty()) {
            System.debug('BlogNotification: No active subscribers found.');
            return;
        }

        // Pass to future method for async HTTP callout
        sendNotificationAsync(
            req.blogTitle,
            req.blogExcerpt,
            req.blogSlug,
            req.blogCategory,
            req.fromEmail,
            req.siteBaseUrl
        );
    }

    // ── Future method — async callout ─────────────────────────────────────
    @future(callout=true)
    private static void sendNotificationAsync(
        String blogTitle,
        String blogExcerpt,
        String blogSlug,
        String blogCategory,
        String fromEmail,
        String siteBaseUrl
    ) {
        // Fetch active subscribers inside future context
        List<Blog_Subscriber__c> subscribers = new ElevatedReader().getActiveSubscribers();
        if (subscribers.isEmpty()) return;

        // Build blog URL
        String blogUrl = siteBaseUrl + '/blogs/blog?slug=' + EncodingUtil.urlEncode(blogSlug, 'UTF-8');

        List<Map<String, Object>> messageVersions = new List<Map<String, Object>>();

        for (Blog_Subscriber__c sub : subscribers) {
            Map<String, Object> version = new Map<String, Object>{
                'to' => new List<Map<String, String>>{
                    new Map<String, String>{
                        'email' => sub.Email__c,
                        'name'  => sub.Name
                    }
                },
                'params' => new Map<String, String>{
                    'subscriberName' => sub.Name,
                    'blogTitle'      => blogTitle,
                    'blogExcerpt'    => blogExcerpt != null ? blogExcerpt : '',
                    'blogCategory'   => blogCategory != null ? blogCategory : '',
                    'blogUrl'        => blogUrl
                }
            };
            messageVersions.add(version);
        }

        // Build HTML email body using Brevo params syntax {{params.x}}
        String htmlContent = buildHtmlTemplate();

        // Build full Brevo payload
        Map<String, Object> payload = new Map<String, Object>{
            'sender' => new Map<String, String>{
                'name'  => 'Govind Singh Solanki',
                'email' => fromEmail
            },
            'subject'         => 'New Blog Post: {{params.blogTitle}}',
            'htmlContent'     => htmlContent,
            'messageVersions' => messageVersions
        };

        // Make callout
        Http http        = new Http();
        HttpRequest hReq = new HttpRequest();
        hReq.setEndpoint('callout:Brevo/smtp/email');
        hReq.setMethod('POST');
        hReq.setHeader('content-type', 'application/json');
        hReq.setBody(JSON.serialize(payload));
        hReq.setTimeout(30000);

        HttpResponse hRes = http.send(hReq);

        if (hRes.getStatusCode() == 201) {
            System.debug('BlogNotification: Emails sent successfully to ' + subscribers.size() + ' subscribers.');
        } else {
            System.debug('BlogNotification error: ' + hRes.getStatusCode() + ' — ' + hRes.getBody());
        }
    }

    // ── HTML email template ───────────────────────────────────────────────
    private static String buildHtmlTemplate() {
        return '<!DOCTYPE html>' +
        '<html lang="en">' +
        '<head>' +
            '<meta charset="UTF-8"/>' +
            '<meta name="viewport" content="width=device-width, initial-scale=1.0"/>' +
            '<title>New Blog Post</title>' +
        '</head>' +
        '<body style="margin:0;padding:0;background-color:#f8fafc;font-family:\'Segoe UI\',Arial,sans-serif;">' +

            // Outer wrapper
            '<table width="100%" cellpadding="0" cellspacing="0" style="background-color:#f8fafc;padding:40px 0;">' +
            '<tr><td align="center">' +

            // Card
            '<table width="600" cellpadding="0" cellspacing="0" style="max-width:600px;width:100%;background:#ffffff;border-radius:16px;overflow:hidden;box-shadow:0 4px 24px rgba(0,0,0,0.08);">' +

                // Header
                '<tr>' +
                    '<td style="background:linear-gradient(135deg,#0070d2,#1589ee);padding:32px 40px;text-align:center;">' +
                        '<p style="margin:0 0 4px 0;color:rgba(255,255,255,0.8);font-size:13px;letter-spacing:0.08em;text-transform:uppercase;">Salesforce Developer Blog</p>' +
                        '<h1 style="margin:0;color:#ffffff;font-size:22px;font-weight:700;letter-spacing:-0.02em;">New Post Published 🚀</h1>' +
                    '</td>' +
                '</tr>' +

                // Category badge
                '<tr>' +
                    '<td style="padding:24px 40px 0;text-align:center;">' +
                        '<span style="display:inline-block;background:#e8f4ff;color:#0070d2;font-size:11px;font-weight:700;letter-spacing:0.06em;text-transform:uppercase;padding:4px 14px;border-radius:999px;">{{params.blogCategory}}</span>' +
                    '</td>' +
                '</tr>' +

                // Blog title
                '<tr>' +
                    '<td style="padding:20px 40px 0;">' +
                        '<h2 style="margin:0;font-size:22px;font-weight:800;color:#1a1a2e;line-height:1.3;letter-spacing:-0.02em;">{{params.blogTitle}}</h2>' +
                    '</td>' +
                '</tr>' +

                // Excerpt
                '<tr>' +
                    '<td style="padding:14px 40px 0;">' +
                        '<p style="margin:0;font-size:15px;color:#5a6a7e;line-height:1.7;">{{params.blogExcerpt}}</p>' +
                    '</td>' +
                '</tr>' +

                // CTA Button
                '<tr>' +
                    '<td style="padding:28px 40px;">' +
                        '<a href="{{params.blogUrl}}" style="display:inline-block;background:linear-gradient(135deg,#0070d2,#1589ee);color:#ffffff;font-size:15px;font-weight:600;text-decoration:none;padding:14px 32px;border-radius:8px;box-shadow:0 4px 14px rgba(0,112,210,0.3);">Read Full Post →</a>' +
                    '</td>' +
                '</tr>' +

                // Divider
                '<tr>' +
                    '<td style="padding:0 40px;">' +
                        '<hr style="border:none;border-top:1px solid #e2eaf4;margin:0;"/>' +
                    '</td>' +
                '</tr>' +

                // Footer
                '<tr>' +
                    '<td style="padding:24px 40px;text-align:center;">' +
                        '<p style="margin:0 0 6px 0;font-size:13px;color:#9aaabb;">Hi {{params.subscriberName}}, you\'re receiving this because you subscribed to Govind\'s Salesforce Blog.</p>' +
                        '<p style="margin:0;font-size:12px;color:#b0bec5;">Govind Singh Solanki · Salesforce Developer</p>' +
                    '</td>' +
                '</tr>' +

            '</table>' +

            '</td></tr></table>' +
        '</body>' +
        '</html>';
    }

    // ── Elevated reader — bypasses sharing for subscriber query ───────────
    private without sharing class ElevatedReader {
        public List<Blog_Subscriber__c> getActiveSubscribers() {
            return [
                SELECT Id, Name, Email__c
                FROM Blog_Subscriber__c
                WHERE Is_Active__c = true
                ORDER BY Subscription_Date__c ASC
            ];
        }
    }

    // ── Invocable request wrapper ─────────────────────────────────────────
    public class BlogNotificationRequest {
        @InvocableVariable(required=true  label='Blog Title')
        public String blogTitle;

        @InvocableVariable(required=false label='Blog Excerpt')
        public String blogExcerpt;

        @InvocableVariable(required=true  label='Blog Slug')
        public String blogSlug;

        @InvocableVariable(required=false label='Blog Category')
        public String blogCategory;

        @InvocableVariable(required=true  label='From Email (verified Brevo sender)')
        public String fromEmail;

        @InvocableVariable(required=true  label='Site Base URL (e.g. https://yoursite.com)')
        public String siteBaseUrl;
    }

}