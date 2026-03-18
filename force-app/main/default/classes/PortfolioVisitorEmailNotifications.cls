public with sharing class PortfolioVisitorEmailNotifications {
    
    // private Id leadId;
    // private static final String SELF_EMAIL_TEMPLATE_ID = '00XgK00000DGSs5UAH';
    //private static final String SELF_EMAIL_TEMPLATE_ID = '00XgK00000DUvPbUAL';
    // private static final String PORTFOLIO_VISITOR_EMAIL_TEMPLATE_ID = '00XgK00000DFpE4UAL';
    //private static final String PORTFOLIO_VISITOR_EMAIL_TEMPLATE_ID = '00XgK00000DUnVLUA1';
    private static final String ORG_WIDE_EMAIL_ID = '0D2gK0000001gGXSAY';
    private static final String FROM_EMAIL = 'gssolanki30@gmail.com';
    private static final String FROM_NAME = 'Govind Singh Solanki';
    private static final String ADMIN_EMAIL = 'gssolanki30@gmail.com';
    private static final String SITE_BASE_URL = 'https://govindsinghsolanki-dev-ed.develop.my.site.com/portfolio';

    private without sharing class ElevatedReader {
        public Lead findByLeadId(Id leadId) {
            return [
                SELECT Id, FirstName, LastName, Email, Subject__c, Description, CreatedDate FROM Lead WHERE Id = :leadId
            ].get(0);
        }
    }

    public static void sendVisitorEmails(Id leadId) {
        Lead ld = new ElevatedReader().findByLeadId(leadId);

        String visitorName = ((ld.FirstName != null ? ld.FirstName : '') +
                             (ld.FirstName != null && ld.LastName != null ? ' ' : '') +
                             (ld.LastName  != null ? ld.LastName  : '')).trim();
        String subject     = ld.Subject__c  != null ? ld.Subject__c  : '(No subject)';
        String message     = ld.Description != null ? ld.Description : '(No message)';
        String submittedAt = ld.CreatedDate.format('dd MMM yyyy, hh:mm a', 'Asia/Kolkata');
        String firstName   = ld.FirstName   != null ? ld.FirstName   : 'there';

        sendEmailsAsync(visitorName, firstName, ld.Email, subject, message, submittedAt);
    }

    @future(callout=true)
    private static void sendEmailsAsync( String visitorName, String firstName, String visitorEmail, String subject, String message, String submittedAt) {
        // 1. Admin notification
        sendEmail(
            ADMIN_EMAIL,
            FROM_NAME,
            'New Portfolio Message from ' + visitorName,
            buildAdminHtml(visitorName, visitorEmail, subject, message, submittedAt)
        );

        // 2. Visitor confirmation
        sendEmail(
            visitorEmail,
            visitorName,
            'Thanks for reaching out, ' + firstName + '!',
            buildVisitorHtml(visitorName, firstName, subject, message)
        );
    }

    // ── Brevo HTTP callout ────────────────────────────────────────────────
    private static void sendEmail( String toEmail, String toName, String subject, String htmlContent) {
        Map<String, Object> payload = new Map<String, Object>{
            'sender' => new Map<String, String>{
                'name'  => FROM_NAME,
                'email' => FROM_EMAIL
            },
            'to' => new List<Map<String, String>>{
                new Map<String, String>{
                    'email' => toEmail,
                    'name'  => toName
                }
            },
            'subject'     => subject,
            'htmlContent' => htmlContent
        };

        Http http        = new Http();
        HttpRequest hReq = new HttpRequest();
        hReq.setEndpoint('callout:Brevo/smtp/email');
        hReq.setMethod('POST');
        hReq.setHeader('content-type', 'application/json');
        hReq.setBody(JSON.serialize(payload));
        hReq.setTimeout(10000);

        HttpResponse hRes = http.send(hReq);

        if (hRes.getStatusCode() == 201) {
            System.debug('Brevo: email sent to ' + toEmail);
        } else {
            System.debug('Brevo error (' + toEmail + '): ' + hRes.getStatusCode() + ' — ' + hRes.getBody());
        }
    }

    // ── Shared outer wrapper ──────────────────────────────────────────────
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

    private static String buildHeader(String gradient, String emoji, String headline, String subline) {
        return '<tr><td style="background:' + gradient + ';padding:32px 40px;text-align:center;">' +
            '<p style="margin:0 0 6px 0;color:rgba(255,255,255,0.85);font-size:11px;font-weight:600;letter-spacing:0.1em;text-transform:uppercase;">Salesforce Developer Portfolio</p>' +
            '<h1 style="margin:0 0 6px 0;color:#ffffff;font-size:22px;font-weight:800;letter-spacing:-0.02em;">' + emoji + '&nbsp;' + headline + '</h1>' +
            '<p style="margin:0;color:rgba(255,255,255,0.8);font-size:13px;">' + subline + '</p>' +
        '</td></tr>';
    }

    private static String buildFooter(String note) {
        return
        '<tr><td style="padding:24px 40px 0;"><hr style="border:none;border-top:1px solid #e2eaf4;margin:0;"/></td></tr>' +
        '<tr><td style="padding:20px 40px 28px;text-align:center;">' +
            '<p style="margin:0 0 4px 0;font-size:12px;color:#9aaabb;">' + note + '</p>' +
            '<p style="margin:0;font-size:12px;color:#b0bec5;">Govind Singh Solanki &middot; Salesforce Developer &middot; Pimpri-Chinchwad, IN</p>' +
        '</td></tr>';
    }

    private static String infoRow(String label, String value, Boolean isLast) {
        String border = isLast ? 'none' : '1px solid #f0f4f8';
        return '<tr>' +
            '<td style="padding:12px 16px;font-size:11px;font-weight:700;color:#9aaabb;text-transform:uppercase;letter-spacing:0.06em;width:120px;vertical-align:top;border-bottom:' + border + ';">' + label + '</td>' +
            '<td style="padding:12px 16px;font-size:14px;color:#2c3e50;line-height:1.6;vertical-align:top;border-bottom:' + border + ';">' + value + '</td>' +
        '</tr>';
    }

    // ── ADMIN NOTIFICATION ────────────────────────────────────────────────
    private static String buildAdminHtml(
        String visitorName,
        String visitorEmail,
        String subject,
        String message,
        String submittedAt
    ) {
        String rows =
            buildHeader(
                'linear-gradient(135deg,#1a1a2e,#2d3561)',
                '&#128236;',
                'New Portfolio Message',
                'Someone reached out via your portfolio contact form'
            ) +
            '<tr><td style="padding:24px 40px 0;text-align:center;">' +
                '<span style="display:inline-block;background:#fff3cd;color:#856404;font-size:11px;font-weight:700;letter-spacing:0.05em;text-transform:uppercase;padding:5px 14px;border-radius:999px;border:1px solid #ffc107;">Action Required &mdash; Reply to Visitor</span>' +
            '</td></tr>' +
            '<tr><td style="padding:20px 40px 0;">' +
                '<table width="100%" cellpadding="0" cellspacing="0" style="border:1px solid #e2eaf4;border-radius:10px;overflow:hidden;">' +
                    infoRow('From',      visitorName, false) +
                    infoRow('Email',     '<a href="mailto:' + visitorEmail + '" style="color:#0070d2;text-decoration:none;">' + visitorEmail + '</a>', false) +
                    infoRow('Subject',   subject,     false) +
                    infoRow('Message',   message,     false) +
                    infoRow('Submitted', submittedAt, true) +
                '</table>' +
            '</td></tr>' +
            '<tr><td style="padding:24px 40px 8px;">' +
                '<a href="mailto:' + visitorEmail + '?subject=Re: ' + subject + '" style="display:inline-block;background:linear-gradient(135deg,#1a1a2e,#2d3561);color:#ffffff;font-size:14px;font-weight:600;text-decoration:none;padding:13px 28px;border-radius:8px;box-shadow:0 4px 14px rgba(26,26,46,0.3);">' +
                    'Reply to ' + visitorName + ' &rarr;' +
                '</a>' +
            '</td></tr>' +
            buildFooter('This notification was sent to you because someone submitted the contact form on your portfolio.');

        return wrapEmail(rows);
    }

    // ── VISITOR CONFIRMATION ──────────────────────────────────────────────
    private static String buildVisitorHtml(
        String visitorName,
        String firstName,
        String subject,
        String message
    ) {
        String rows =
            buildHeader(
                'linear-gradient(135deg,#0070d2,#1589ee)',
                '&#9989;',
                'Message Received!',
                'I\'ll get back to you as soon as possible'
            ) +
            '<tr><td style="padding:32px 40px 0;">' +
                '<p style="margin:0 0 14px 0;font-size:16px;font-weight:700;color:#1a1a2e;">Hi ' + firstName + ',</p>' +
                '<p style="margin:0 0 14px 0;font-size:15px;color:#5a6a7e;line-height:1.75;">Thanks for reaching out! I\'ve received your message and will get back to you within <strong style="color:#0070d2;">1&ndash;2 business days</strong>.</p>' +
                '<p style="margin:0 0 16px 0;font-size:15px;color:#5a6a7e;line-height:1.75;">Here\'s a copy of what you sent:</p>' +
            '</td></tr>' +
            '<tr><td style="padding:0 40px;">' +
                '<table width="100%" cellpadding="0" cellspacing="0" style="background:#f8fafc;border:1px solid #e2eaf4;border-left:4px solid #0070d2;border-radius:0 8px 8px 0;">' +
                    '<tr><td style="padding:16px 20px;">' +
                        '<p style="margin:0 0 4px 0;font-size:11px;font-weight:700;color:#9aaabb;text-transform:uppercase;letter-spacing:0.06em;">Subject</p>' +
                        '<p style="margin:0 0 14px 0;font-size:14px;font-weight:600;color:#1a1a2e;">' + subject + '</p>' +
                        '<p style="margin:0 0 4px 0;font-size:11px;font-weight:700;color:#9aaabb;text-transform:uppercase;letter-spacing:0.06em;">Message</p>' +
                        '<p style="margin:0;font-size:14px;color:#2c3e50;line-height:1.65;">' + message + '</p>' +
                    '</td></tr>' +
                '</table>' +
            '</td></tr>' +
            '<tr><td style="padding:24px 40px 0;">' +
                '<p style="margin:0 0 10px 0;font-size:14px;font-weight:700;color:#1a1a2e;">While you wait, you might enjoy:</p>' +
                '<table cellpadding="0" cellspacing="0">' +
                    '<tr><td style="padding:4px 0;font-size:14px;color:#5a6a7e;">&#128209; Reading my latest blog posts on Salesforce</td></tr>' +
                    '<tr><td style="padding:4px 0;font-size:14px;color:#5a6a7e;">&#128241; Connecting with me on LinkedIn</td></tr>' +
                    '<tr><td style="padding:4px 0;font-size:14px;color:#5a6a7e;">&#128187; Checking out my projects on GitHub</td></tr>' +
                '</table>' +
            '</td></tr>' +
            '<tr><td style="padding:24px 40px 8px;">' +
                '<a href="' + SITE_BASE_URL + '/blogs" style="display:inline-block;background:linear-gradient(135deg,#0070d2,#1589ee);color:#ffffff;font-size:14px;font-weight:600;text-decoration:none;padding:13px 28px;border-radius:8px;box-shadow:0 4px 14px rgba(0,112,210,0.3);">Browse the Blog &rarr;</a>' +
            '</td></tr>' +
            buildFooter('You\'re receiving this because you submitted the contact form on Govind\'s Salesforce Developer Portfolio.');

        return wrapEmail(rows);
    }

}